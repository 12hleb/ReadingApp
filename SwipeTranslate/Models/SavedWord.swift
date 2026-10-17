import Foundation
import SwiftData

@Model
final class SavedWord {
    @Attribute(.unique) var id: UUID
    var originalText: String
    var translatedText: String
    var originalSentence: String?
    var createdAt: Date
    var book: Book?

    init(originalText: String, translatedText: String, originalSentence: String? = nil,
         book: Book? = nil, now: Date = .now) {
        id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.originalSentence = originalSentence
        self.book = book
        createdAt = now
    }
}
