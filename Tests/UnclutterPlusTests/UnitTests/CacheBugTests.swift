import Foundation
import XCTest
@testable import UnclutterPlus

final class CacheBugTests: XCTestCase {
    func testLRUCacheClearRecordsEvictedItemCount() async {
        let cache = LRUCache<UUID, Note>(maxSize: 10)
        let notes = [
            makeNote(title: "One"),
            makeNote(title: "Two"),
            makeNote(title: "Three"),
        ]

        for note in notes {
            await cache.set(note.id, note)
        }

        await cache.clear()

        let statistics = await cache.getStatistics()
        XCTAssertEqual(statistics.currentSize, 0)
        XCTAssertEqual(statistics.evictionCount, notes.count)
    }

    private func makeNote(title: String) -> Note {
        Note(title: title, content: "Cache test content for \(title)")
    }
}
