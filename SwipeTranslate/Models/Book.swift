import Foundation
import SwiftData

@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Relative to Application Support/Covers, never an absolute sandbox path.
    var coverImagePath: String?
    var createdAt: Date
    var updatedAt: Date
    var lastReadAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \SavedWord.book)
    var savedWords: [SavedWord] = []

    init(title: String, coverImagePath: String? = nil, now: Date = .now) {
        id = UUID()
        self.title = title
        self.coverImagePath = coverImagePath
        createdAt = now
        updatedAt = now
    }
}
