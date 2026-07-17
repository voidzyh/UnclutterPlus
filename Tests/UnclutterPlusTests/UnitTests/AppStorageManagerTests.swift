import XCTest
@testable import UnclutterPlus

final class AppStorageManagerTests: XCTestCase {
    @MainActor
    func testSharedNotesServiceIsAccessible() {
        let notesService = AppStorageManager.shared.notesService

        XCTAssertEqual(ObjectIdentifier(type(of: notesService)), ObjectIdentifier(NotesService.self))
    }
}
