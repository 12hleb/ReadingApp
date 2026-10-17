import Foundation
import SwiftData

enum VocabularyError: LocalizedError {
    case emptyTitle, emptyTranslation
    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Please enter a book title."
        case .emptyTranslation: "Select some text and finish translating before saving."
        }
    }
}

enum SaveWordResult {
    case inserted(SavedWord)
    case existing(SavedWord)
    var isDuplicate: Bool { if case .existing = self { return true }; return false }
}

@MainActor
struct VocabularyRepository {
    let context: ModelContext

    static func duplicateKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
    }

    @discardableResult
    func createBook(title: String, coverPath: String?) throws -> Book {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw VocabularyError.emptyTitle }
        let book = Book(title: title, coverImagePath: coverPath)
        context.insert(book)
        do { try context.save(); return book }
        catch { context.rollback(); throw error }
    }

    func saveWord(original: String, translation: String, sentence: String?, in book: Book) throws -> SaveWordResult {
        let original = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty, !translation.isEmpty else { throw VocabularyError.emptyTranslation }
        let key = Self.duplicateKey(original)
        if let existing = book.savedWords.first(where: { Self.duplicateKey($0.originalText) == key }) {
            // Keep any translation the reader has edited. Duplicates are scoped to this book.
            return .existing(existing)
        }
        let word = SavedWord(originalText: original, translatedText: translation,
                             originalSentence: sentence, book: book)
        context.insert(word)
        book.updatedAt = .now
        do { try context.save(); return .inserted(word) }
        catch { context.rollback(); throw error }
    }

    func delete(_ word: SavedWord) throws {
        word.book?.updatedAt = .now
        context.delete(word)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func update(_ word: SavedWord, translation: String) throws {
        let value = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw VocabularyError.emptyTranslation }
        word.translatedText = value
        word.book?.updatedAt = .now
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
