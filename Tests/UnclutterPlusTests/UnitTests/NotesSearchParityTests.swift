import XCTest
@testable import UnclutterPlus

final class NotesSearchParityTests: XCTestCase {
    private var notesService: NotesService!
    private var storage: UnifiedNoteStorage!
    private var storageRoot: URL!

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()

        storageRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UnclutterPlusTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        storage = UnifiedNoteStorage(
            configuration: StorageConfiguration(baseURL: storageRoot, cacheSizeLimit: 100)
        )
        notesService = NotesService(storage: storage)
    }

    override func tearDownWithError() throws {
        notesService = nil
        storage = nil

        if let storageRoot {
            try? FileManager.default.removeItem(at: storageRoot)
        }
        storageRoot = nil

        try super.tearDownWithError()
    }

    @MainActor
    func testEnterpriseSearchMatchesTitleContentTagsCaseEmptyAndDeleteParity() async throws {
        let alphaCreated = await notesService.createNote(
            title: "Alpha Roadmap",
            content: String(repeating: "introductory filler ", count: 16) + "deepbodyneedle lives outside preview",
            tags: ["planning"]
        )
        XCTAssertTrue(alphaCreated)

        let betaCreated = await notesService.createNote(
            title: "Beta Archive",
            content: "release notes for mixed casing",
            tags: ["TagNeedle"]
        )
        XCTAssertTrue(betaCreated)

        let gammaCreated = await notesService.createNote(
            title: "Gamma MixedCaseTitle",
            content: "ordinary body",
            tags: ["reference"]
        )
        XCTAssertTrue(gammaCreated)

        let alphaID = try noteID(titled: "Alpha Roadmap")
        let betaID = try noteID(titled: "Beta Archive")
        let gammaID = try noteID(titled: "Gamma MixedCaseTitle")

        try await assertSearch("roadmap", returnsExactly: [alphaID])
        try await assertSearch("deepbodyneedle", returnsExactly: [alphaID])
        try await assertSearch("tagneedle", returnsExactly: [betaID])
        try await assertSearch("mixedcasetitle", returnsExactly: [gammaID])
        try await assertSearch("", returnsExactly: [alphaID, betaID, gammaID])

        guard let beta = await notesService.getNote(id: betaID) else {
            return XCTFail("Expected Beta Archive to be readable before delete")
        }

        let betaDeleted = await notesService.deleteNote(beta)
        XCTAssertTrue(betaDeleted)

        try await assertSearch("tagneedle", returnsExactly: [])
        try await assertSearch("deepbodyneedle", returnsExactly: [alphaID])
        try await assertSearch("", returnsExactly: [alphaID, gammaID])
    }

    @MainActor
    func testMetadataPlusContentBeyondPreviewOrSemanticsPreservesIndexOrder() async throws {
        // Note A: "zephyr" in TITLE only
        let aOK = await notesService.createNote(
            title: "Zephyr Planning",
            content: "project background details with no keyword",
            tags: ["roadmap"]
        )
        XCTAssertTrue(aOK)

        // Note B: unrelated
        let bOK = await notesService.createNote(
            title: "Quarterly Report",
            content: "standard quarterly summary text",
            tags: ["finance"]
        )
        XCTAssertTrue(bOK)

        // Note C: "zephyr" in TAG only
        let cOK = await notesService.createNote(
            title: "Component Library",
            content: "collection of reusable modules",
            tags: ["zephyr-module"]
        )
        XCTAssertTrue(cOK)

        // Note D: "zephyr" in CONTENT beyond 200-char preview
        let dOK = await notesService.createNote(
            title: "Deep Archive",
            content: String(repeating: "filler block for preview boundary ", count: 20) + "zephyr hidden deep in body",
            tags: ["storage"]
        )
        XCTAssertTrue(dOK)

        // Note E: "zephyr" in BOTH title AND content (dedup check)
        let eOK = await notesService.createNote(
            title: "Zephyr Integration",
            content: "zephyr appears in both title and full text body",
            tags: ["integration"]
        )
        XCTAssertTrue(eOK)

        let idA = try noteID(titled: "Zephyr Planning")
        let idB = try noteID(titled: "Quarterly Report")
        let idC = try noteID(titled: "Component Library")
        let idD = try noteID(titled: "Deep Archive")
        let idE = try noteID(titled: "Zephyr Integration")

        let results = await notesService.searchNotes(query: "zephyr")
        let resultIDs = results.map(\.id)

        // A (title), C (tag), D (content-beyond-preview), E (title+content) must all appear
        XCTAssertTrue(resultIDs.contains(idA), "Title match (Zephyr Planning) missing")
        XCTAssertFalse(resultIDs.contains(idB), "Unrelated note should not appear")
        XCTAssertTrue(resultIDs.contains(idC), "Tag match (Component Library) missing")
        XCTAssertTrue(resultIDs.contains(idD), "Content-beyond-preview match (Deep Archive) missing")
        XCTAssertTrue(resultIDs.contains(idE), "Title+content match (Zephyr Integration) missing")

        // No duplicates
        XCTAssertEqual(resultIDs.count, Set(resultIDs).count, "Duplicate IDs in results")

        // Preserve creation/index order: A, C, D, E
        let expectedOrder = [idA, idC, idD, idE]
        XCTAssertEqual(resultIDs, expectedOrder, "Results must preserve noteIndexes order")

        // Empty query returns all
        try await assertSearch("", returnsExactly: [idA, idB, idC, idD, idE])
    }

    @MainActor
    func testSearchReturnsMetadataAndFullContentMatchesInIndexOrderWithoutDuplicates() async throws {
        let titleCreated = await notesService.createNote(
            title: "Needle Planning",
            content: "metadata hit only",
            tags: ["project"]
        )
        XCTAssertTrue(titleCreated)

        let contentCreated = await notesService.createNote(
            title: "Content Archive",
            content: String(repeating: "preview filler ", count: 24) + "needle appears after preview",
            tags: ["archive"]
        )
        XCTAssertTrue(contentCreated)

        let unrelatedCreated = await notesService.createNote(
            title: "Unrelated",
            content: "ordinary body",
            tags: ["misc"]
        )
        XCTAssertTrue(unrelatedCreated)

        let titleID = try noteID(titled: "Needle Planning")
        let contentID = try noteID(titled: "Content Archive")

        let results = await notesService.searchNotes(query: "needle")
        let resultIDs = results.map(\.id)

        XCTAssertEqual(resultIDs, [titleID, contentID])
        XCTAssertEqual(Set(resultIDs).count, resultIDs.count)
    }

    @MainActor
    private func noteID(titled title: String) throws -> UUID {
        try XCTUnwrap(
            notesService.noteIndexes.first(where: { $0.title == title })?.id,
            "Expected note titled \(title) to be indexed"
        )
    }

    @MainActor
    private func assertSearch(
        _ query: String,
        returnsExactly expectedIDs: [UUID],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let results = await notesService.searchNotes(query: query)
        XCTAssertEqual(results.map(\.id), expectedIDs, file: file, line: line)
    }
}
