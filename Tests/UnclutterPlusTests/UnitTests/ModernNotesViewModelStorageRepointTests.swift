import XCTest
@testable import UnclutterPlus

final class ModernNotesViewModelStorageRepointTests: XCTestCase {
    func testModernNotesViewModelDoesNotReferenceNotesManagerShared() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/UnclutterPlus/Features/Notes/ModernNotesViewModel.swift")

        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(
            source.contains("NotesManager.shared"),
            "ModernNotesViewModel must use AppStorageManager.shared.notesService instead of NotesManager.shared"
        )
    }

    @MainActor
    func testModernNotesViewModelKeepsModernNotesViewSurface() {
        let viewModel = ModernNotesViewModel()
        let note = Note(title: "Contract", content: "Body", tags: ["task-3"])

        _ = viewModel.statistics
        _ = viewModel.selectedNote
        _ = viewModel.notes
        _ = viewModel.filteredNotes
        _ = viewModel.searchText
        _ = viewModel.isAIOrganizing

        let createNote: () -> Void = viewModel.createNote
        let loadInitialData: () -> Void = viewModel.loadInitialData
        let selectNote: (Note) -> Void = viewModel.selectNote
        let toggleFavorite: (Note) -> Void = viewModel.toggleFavorite
        let deleteNote: (Note) -> Void = viewModel.deleteNote
        let aiOrganize: (OrganizeAction) -> Void = viewModel.aiOrganize
        let aiGenerateTitleAndSummary: () -> Void = viewModel.aiGenerateTitleAndSummary
        let aiAutoTag: () -> Void = viewModel.aiAutoTag
        let exportToObsidian: (Note) -> Void = viewModel.exportToObsidian

        _ = note
        _ = createNote
        _ = loadInitialData
        _ = selectNote
        _ = toggleFavorite
        _ = deleteNote
        _ = aiOrganize
        _ = aiGenerateTitleAndSummary
        _ = aiAutoTag
        _ = exportToObsidian
    }
}
