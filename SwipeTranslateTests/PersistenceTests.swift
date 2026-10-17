import XCTest
import SwiftData
@testable import SwipeTranslate

final class PersistenceTests: XCTestCase {
    @MainActor private func memoryStore() throws -> ModelContainer {
        try ModelContainer(for: Book.self, SavedWord.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @MainActor func testBookCreationTrimsTitleAndPersistsCoverReference() async throws {
        let store = try memoryStore()
        let repository = VocabularyRepository(context: store.mainContext)
        let book = try repository.createBook(title: "  My Book \n", coverPath: "cover.jpg")
        XCTAssertEqual(book.title, "My Book")
        XCTAssertEqual(book.coverImagePath, "cover.jpg")
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertTrue(book.savedWords.isEmpty)
        XCTAssertThrowsError(try repository.createBook(title: " \n ", coverPath: nil))
    }

    @MainActor func testDuplicateIsScopedToBookAndPreservesEditedTranslation() async throws {
        let store = try memoryStore()
        let repository = VocabularyRepository(context: store.mainContext)
        let first = try repository.createBook(title: "One", coverPath: nil)
        let second = try repository.createBook(title: "Two", coverPath: nil)
        let saved = try repository.saveWord(original: "Quiet garden", translation: "тихий сад", sentence: "A quiet garden waits.", in: first)
        guard case .inserted(let word) = saved else { return XCTFail("Expected insertion") }
        try repository.update(word, translation: "спокойный сад")
        let duplicate = try repository.saveWord(original: "  QUIET   garden! ", translation: "replacement", sentence: nil, in: first)
        XCTAssertTrue(duplicate.isDuplicate)
        XCTAssertEqual(first.savedWords.count, 1)
        XCTAssertEqual(word.translatedText, "спокойный сад")
        XCTAssertFalse(try repository.saveWord(original: "quiet garden", translation: "тихий сад", sentence: nil, in: second).isDuplicate)
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<SavedWord>()).count, 2)
    }

    @MainActor func testDeletingBookCascadesOnlyItsVocabulary() async throws {
        let store = try memoryStore()
        let repository = VocabularyRepository(context: store.mainContext)
        let first = try repository.createBook(title: "One", coverPath: nil)
        let second = try repository.createBook(title: "Two", coverPath: nil)
        _ = try repository.saveWord(original: "one", translation: "один", sentence: nil, in: first)
        _ = try repository.saveWord(original: "two", translation: "два", sentence: nil, in: second)
        store.mainContext.delete(first)
        try store.mainContext.save()
        let remaining = try store.mainContext.fetch(FetchDescriptor<SavedWord>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.book?.id, second.id)
    }

    @MainActor func testDeleteWordKeepsBook() async throws {
        let store = try memoryStore()
        let repository = VocabularyRepository(context: store.mainContext)
        let book = try repository.createBook(title: "My Book", coverPath: nil)
        guard case .inserted(let word) = try repository.saveWord(original: "bird", translation: "птица", sentence: nil, in: book) else {
            return XCTFail("Expected insertion")
        }
        try repository.delete(word)
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<Book>()).count, 1)
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<SavedWord>()).count, 0)
    }

    @MainActor func testDiskStoreSurvivesReopeningContainer() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "Library.store")
        let schema = Schema([Book.self, SavedWord.self])
        let configuration = ModelConfiguration(schema: schema, url: url)
        func write() throws -> UUID {
            let store = try ModelContainer(for: schema, configurations: [configuration])
            let repository = VocabularyRepository(context: store.mainContext)
            let book = try repository.createBook(title: "Persistent Book", coverPath: "test-cover.jpg")
            _ = try repository.saveWord(original: "curiosity", translation: "любопытство", sentence: "Her curiosity grew.", in: book)
            return book.id
        }
        let id = try write()
        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let books = try reopened.mainContext.fetch(FetchDescriptor<Book>())
        XCTAssertEqual(books.count, 1)
        XCTAssertEqual(books.first?.id, id)
        XCTAssertEqual(books.first?.coverImagePath, "test-cover.jpg")
        XCTAssertEqual(books.first?.savedWords.first?.translatedText, "любопытство")
        XCTAssertEqual(books.first?.savedWords.first?.originalSentence, "Her curiosity grew.")
    }

    @MainActor func testEmptyTranslationDoesNotInsertVocabulary() async throws {
        let store = try memoryStore()
        let repository = VocabularyRepository(context: store.mainContext)
        let book = try repository.createBook(title: "Book", coverPath: nil)
        XCTAssertThrowsError(try repository.saveWord(original: "word", translation: " \n", sentence: nil, in: book))
        XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<SavedWord>()).count, 0)
    }
}
