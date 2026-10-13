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
    // Defaults preserve the language pair of entries saved before multi-language support.
    var sourceLanguageCode: String = "en"
    var targetLanguageCode: String = "ru"

    var sourceLanguage: ReaderLanguage { ReaderLanguage(rawValue: sourceLanguageCode) ?? .english }
    var targetLanguage: ReaderLanguage { ReaderLanguage(rawValue: targetLanguageCode) ?? .russian }
    var languagePairLabel: String { "\(sourceLanguage.name) → \(targetLanguage.name)" }

    init(originalText: String, translatedText: String, originalSentence: String? = nil,
         book: Book? = nil, now: Date = .now,
         sourceLanguage: ReaderLanguage = .english, targetLanguage: ReaderLanguage = .russian) {
        id = UUID()
        self.originalText = originalText
        self.translatedText = translatedText
        self.originalSentence = originalSentence
        self.book = book
        createdAt = now
        sourceLanguageCode = sourceLanguage.rawValue
        targetLanguageCode = targetLanguage.rawValue
    }
}
