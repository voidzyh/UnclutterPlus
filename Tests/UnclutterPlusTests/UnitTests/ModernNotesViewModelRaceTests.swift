import XCTest
@testable import UnclutterPlus

final class ModernNotesViewModelRaceTests: XCTestCase {
    @MainActor
    func testRapidEditDelayedFirstWritePersistsNewestNoteAndDerivedIndex() async throws {
        let storage = GateControlledNoteStorage()
        let original = Note(title: "Original", content: "Original body")
        try await storage.create([original])

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)
        await viewModel.refresh()

        viewModel.selectNote(original)
        await storage.waitForReadCount(1)
        await drainMainActor()

        await storage.pauseNextUpdates(1)
        viewModel.updateSelectedNote(
            title: "Edit A",
            content: "alpha stale body",
            tags: ["old"]
        )
        await storage.waitForPausedUpdateCount(1)

        viewModel.updateSelectedNote(
            title: "Edit B",
            content: "# Fresh\nnewest persisted words",
            tags: ["new"]
        )

        await storage.releasePausedUpdates()
        try await waitUntil {
            await storage.updateCalledCount >= 2 && !viewModel.isSaving
        }

        let storedNote = await storage.note(id: original.id)
        let persisted = try XCTUnwrap(storedNote)
        XCTAssertEqual(persisted.title, "Edit B")
        XCTAssertEqual(persisted.content, "# Fresh\nnewest persisted words")
        XCTAssertEqual(persisted.tags, ["new"])
        XCTAssertEqual(persisted.preview, "# Fresh\nnewest persisted words")
        XCTAssertEqual(persisted.wordCount, 5)
        XCTAssertEqual(persisted.headings, ["# Fresh"])

        let storedIndex = await storage.index(id: original.id)
        let index = try XCTUnwrap(storedIndex)
        XCTAssertEqual(index.title, "Edit B")
        XCTAssertEqual(index.preview, "# Fresh\nnewest persisted words")
        XCTAssertEqual(index.wordCount, 5)

        XCTAssertEqual(viewModel.selectedNote?.title, "Edit B")
        XCTAssertEqual(viewModel.selectedNote?.wordCount, 5)
        XCTAssertEqual(service.selectedNote?.id, original.id)
        XCTAssertEqual(service.selectedNote?.title, "Edit B")
    }

    @MainActor
    func testRapidSelectDelayedFirstLoadLeavesLatestSelectionInViewModelAndService() async throws {
        let storage = GateControlledNoteStorage()
        let noteA = Note(title: "A", content: "Full A")
        let noteB = Note(title: "B", content: "Full B")
        try await storage.create([noteA, noteB])

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)

        await storage.pauseReads(for: [noteA.id])
        viewModel.selectNote(noteA)
        await storage.waitForPausedReadCount(1)

        viewModel.selectNote(noteB)
        try await waitUntil {
            viewModel.selectedNote?.id == noteB.id && service.selectedNote?.id == noteB.id
        }

        await storage.releasePausedReads()
        try await waitUntil {
            await storage.readCalledCount >= 2
        }
        await drainMainActor()

        XCTAssertEqual(viewModel.selectedNote?.id, noteB.id)
        XCTAssertEqual(viewModel.selectedNote?.title, "B")
        XCTAssertEqual(service.selectedNote?.id, noteB.id)
        XCTAssertEqual(service.selectedNote?.title, "B")
    }

    @MainActor
    func testSelectingOneNoteTriggersOneStorageRead() async throws {
        let storage = GateControlledNoteStorage()
        let note = Note(title: "One", content: "Full body")
        try await storage.create([note])

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)
        viewModel.selectNote(note)

        await storage.waitForReadCount(1)
        await drainMainActor()
        let readCount = await storage.readCalledCount
        XCTAssertEqual(readCount, 1)
    }

    @MainActor
    func testFailedUpdatePublishesViewModelError() async throws {
        let storage = GateControlledNoteStorage()
        let note = Note(title: "Failure", content: "Original")
        try await storage.create([note])
        await storage.setUpdateFailure(true)

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)
        await viewModel.refresh()
        viewModel.selectNote(note)
        viewModel.updateSelectedNote(content: "Rejected")

        try await waitUntil {
            viewModel.error != nil && !viewModel.isSaving
        }
        guard case .updateFailed = viewModel.error else {
            return XCTFail("Expected updateFailed, got \(String(describing: viewModel.error))")
        }
    }

    @MainActor
    func testOneViewModelCreatesOneServiceSubscription() async throws {
        let storage = GateControlledNoteStorage()
        let note = Note(title: "Only", content: "Body")
        try await storage.create([note])

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)
        await viewModel.refresh()

        let baseline = await storage.statisticsCallCount()
        service.objectWillChange.send()
        try await waitUntil {
            await storage.statisticsCallCount() == baseline + 1
        }
        try await Task.sleep(nanoseconds: 150_000_000)

        let statisticsCount = await storage.statisticsCallCount()
        XCTAssertEqual(statisticsCount, baseline + 1)
        XCTAssertNotNil(viewModel)
    }

    @MainActor
    func testAIActionWiringPassesEveryOrganizeActionToInjectedService() async throws {
        let storage = GateControlledNoteStorage()
        let note = Note(title: "AI", content: "Original", tags: ["existing"])
        try await storage.create([note])

        let service = NotesService(storage: storage)
        let aiService = RecordingAIService()
        let viewModel = ModernNotesViewModel(
            notesService: service,
            isAIConfigured: { true },
            makeAIService: { aiService }
        )
        await viewModel.refresh()
        viewModel.selectNote(note)

        for action in OrganizeAction.allCases {
            viewModel.aiOrganize(action: action)
            try await waitUntil {
                await aiService.recordedActions.contains(action) &&
                    viewModel.lastAIAction == action.rawValue &&
                    !viewModel.isAIOrganizing
            }
        }

        let recordedActions = await aiService.recordedActions
        XCTAssertEqual(recordedActions, OrganizeAction.allCases)
        XCTAssertNil(viewModel.aiOrganizeError)
    }

    @MainActor
    func testBatchAIUsesInjectedServiceFactory() async throws {
        let storage = GateControlledNoteStorage()
        let notes = [
            Note(title: "A", content: "First"),
            Note(title: "B", content: "Second")
        ]
        try await storage.create(notes)

        let service = NotesService(storage: storage)
        let aiService = RecordingAIService()
        let viewModel = ModernNotesViewModel(
            notesService: service,
            isAIConfigured: { true },
            makeAIService: { aiService }
        )

        viewModel.aiBatchOrganize(notes: notes)
        try await waitUntil {
            await aiService.recordedActions.count == notes.count &&
                viewModel.lastAIAction == "batchOrganize" &&
                !viewModel.isAIOrganizing
        }

        let recordedActions = await aiService.recordedActions
        XCTAssertEqual(recordedActions, [.polish, .polish])
        XCTAssertNil(viewModel.aiOrganizeError)
    }

    @MainActor
    func testLayoutAndMultiSelectChangesStaySynchronizedWithService() async throws {
        let storage = GateControlledNoteStorage()
        let noteA = Note(title: "A", content: "A")
        let noteB = Note(title: "B", content: "B")
        try await storage.create([noteA, noteB])

        let service = NotesService(storage: storage)
        let viewModel = ModernNotesViewModel(notesService: service)
        await viewModel.refresh()

        viewModel.setViewLayout(.grid)
        XCTAssertEqual(viewModel.viewLayout, .grid)
        XCTAssertEqual(service.viewLayout, .grid)

        viewModel.toggleMultiSelectMode()
        viewModel.selectAllNotes()
        XCTAssertTrue(viewModel.isMultiSelectMode)
        XCTAssertTrue(service.isMultiSelectMode)
        XCTAssertEqual(viewModel.selectedNoteIds, Set([noteA.id, noteB.id]))
        XCTAssertEqual(service.selectedNoteIds, viewModel.selectedNoteIds)

        viewModel.toggleMultiSelectMode()
        XCTAssertFalse(viewModel.isMultiSelectMode)
        XCTAssertFalse(service.isMultiSelectMode)
        XCTAssertTrue(viewModel.selectedNoteIds.isEmpty)
        XCTAssertTrue(service.selectedNoteIds.isEmpty)
    }

    @MainActor
    private func drainMainActor() async {
        await Task.yield()
        await Task.yield()
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }
}

private actor RecordingAIService: AIService {
    nonisolated let displayName = "Recording AI"
    private(set) var recordedActions: [OrganizeAction] = []

    func organize(content: String, instruction: OrganizeInstruction) async throws -> OrganizeResult {
        recordedActions.append(instruction.action)
        return OrganizeResult(
            content: "\(content)-\(instruction.action.rawValue)",
            title: nil,
            summary: nil,
            tags: []
        )
    }

    func cluster(items: [String], existingTopics: [String]) async throws -> [AICluster] {
        []
    }

    func summarize(cluster: AICluster) async throws -> DocumentDraft {
        DocumentDraft(title: cluster.topic, content: cluster.items.joined(separator: "\n"))
    }
}

private actor GateControlledNoteStorage: UnifiedStorageProtocol {
    typealias Item = Note
    typealias Index = NoteIndex

    private var items: [UUID: Note] = [:]
    private var indexes: [UUID: NoteIndex] = [:]
    private var pausedUpdateContinuations: [CheckedContinuation<Void, Never>] = []
    private var pausedReadContinuations: [CheckedContinuation<Void, Never>] = []
    private var updateWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var readWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var pausedUpdateWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var pausedReadWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var updatesToPause = 0
    private var readIDsToPause = Set<UUID>()
    private var shouldFailUpdates = false

    private(set) var updateCalledCount = 0
    private(set) var readCalledCount = 0
    private(set) var getAllIndexesCalledCount = 0
    private(set) var getStatisticsCalledCount = 0

    func statisticsCallCount() -> Int {
        getStatisticsCalledCount
    }

    func pauseNextUpdates(_ count: Int) {
        updatesToPause += count
    }

    func pauseReads(for ids: Set<UUID>) {
        readIDsToPause.formUnion(ids)
    }

    func setUpdateFailure(_ shouldFail: Bool) {
        shouldFailUpdates = shouldFail
    }

    func waitForPausedUpdateCount(_ count: Int) async {
        if pausedUpdateContinuations.count >= count { return }
        await withCheckedContinuation { continuation in
            pausedUpdateWaiters.append((count, continuation))
        }
    }

    func waitForPausedReadCount(_ count: Int) async {
        if pausedReadContinuations.count >= count { return }
        await withCheckedContinuation { continuation in
            pausedReadWaiters.append((count, continuation))
        }
    }

    func waitForReadCount(_ count: Int) async {
        if readCalledCount >= count { return }
        await withCheckedContinuation { continuation in
            readWaiters.append((count, continuation))
        }
    }

    func releasePausedUpdates() {
        let continuations = pausedUpdateContinuations
        pausedUpdateContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func releasePausedReads() {
        let continuations = pausedReadContinuations
        pausedReadContinuations.removeAll()
        continuations.forEach { $0.resume() }
    }

    func note(id: UUID) -> Note? {
        items[id]
    }

    func index(id: UUID) -> NoteIndex? {
        indexes[id]
    }

    func create(_ items: [Note]) async throws {
        for item in items {
            self.items[item.id] = item
            indexes[item.id] = NoteIndex(from: item)
        }
    }

    func read(id: UUID) async throws -> Note? {
        readCalledCount += 1
        resumeSatisfiedReadWaiters()

        if readIDsToPause.remove(id) != nil {
            await withCheckedContinuation { continuation in
                pausedReadContinuations.append(continuation)
                resumeSatisfiedPausedReadWaiters()
            }
        }

        return items[id]
    }

    func readBatch(ids: [UUID]) async throws -> [Note] {
        try await ids.asyncCompactMap { try await read(id: $0) }
    }

    func update(_ items: [Note]) async throws {
        updateCalledCount += 1
        resumeSatisfiedUpdateWaiters()

        if shouldFailUpdates {
            throw StorageError.writeFailed(underlying: TestStorageFailure())
        }

        if updatesToPause > 0 {
            updatesToPause -= 1
            await withCheckedContinuation { continuation in
                pausedUpdateContinuations.append(continuation)
                resumeSatisfiedPausedUpdateWaiters()
            }
        }

        for item in items {
            self.items[item.id] = item
            indexes[item.id] = NoteIndex(from: item)
        }
    }

    func delete(ids: [UUID]) async throws {
        for id in ids {
            items.removeValue(forKey: id)
            indexes.removeValue(forKey: id)
        }
    }

    func search(query: String, limit: Int?) async throws -> [NoteIndex] {
        Array(indexes.values)
    }

    func getAllIndexes(limit: Int?, offset: Int?) async throws -> [NoteIndex] {
        getAllIndexesCalledCount += 1
        return Array(indexes.values)
    }

    func filter(by predicate: @escaping (NoteIndex) -> Bool, limit: Int?) async throws -> [NoteIndex] {
        Array(indexes.values).filter(predicate)
    }

    func count() async throws -> Int {
        items.count
    }

    func clear() async throws {
        items.removeAll()
        indexes.removeAll()
    }

    func getStatistics() async throws -> StorageStatistics {
        getStatisticsCalledCount += 1
        return StorageStatistics(
            totalItems: items.count,
            totalSize: 0,
            cacheSize: items.count,
            lastModified: Date(),
            storageType: .simple
        )
    }

    private func resumeSatisfiedUpdateWaiters() {
        let ready = updateWaiters.filter { updateCalledCount >= $0.0 }
        updateWaiters.removeAll { updateCalledCount >= $0.0 }
        ready.forEach { $0.1.resume() }
    }

    private func resumeSatisfiedReadWaiters() {
        let ready = readWaiters.filter { readCalledCount >= $0.0 }
        readWaiters.removeAll { readCalledCount >= $0.0 }
        ready.forEach { $0.1.resume() }
    }

    private func resumeSatisfiedPausedUpdateWaiters() {
        let ready = pausedUpdateWaiters.filter { pausedUpdateContinuations.count >= $0.0 }
        pausedUpdateWaiters.removeAll { pausedUpdateContinuations.count >= $0.0 }
        ready.forEach { $0.1.resume() }
    }

    private func resumeSatisfiedPausedReadWaiters() {
        let ready = pausedReadWaiters.filter { pausedReadContinuations.count >= $0.0 }
        pausedReadWaiters.removeAll { pausedReadContinuations.count >= $0.0 }
        ready.forEach { $0.1.resume() }
    }
}

private struct TestStorageFailure: Error {}

private extension Sequence {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async throws -> [T] {
        var result: [T] = []
        for element in self {
            if let value = try await transform(element) {
                result.append(value)
            }
        }
        return result
    }
}
