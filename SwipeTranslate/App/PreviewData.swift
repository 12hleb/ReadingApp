import SwiftData
import Foundation

@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try ModelContainer(for: Book.self, SavedWord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let book = Book(title: "The Secret Garden")
            container.mainContext.insert(book)
            let word = SavedWord(originalText: "curiosity", translatedText: "любопытство",
                originalSentence: "Her curiosity led her into the garden.", book: book)
            container.mainContext.insert(word)
            try container.mainContext.save()
            return container
        } catch { fatalError("Preview store failed: \(error)") }
    }()
}
