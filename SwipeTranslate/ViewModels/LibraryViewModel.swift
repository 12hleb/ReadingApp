import SwiftUI
import SwiftData

@MainActor @Observable
final class LibraryViewModel {
    var showingAddBook = false
    var error: String?

    func delete(_ book: Book, context: ModelContext) {
        let cover = book.coverImagePath
        context.delete(book)
        do {
            try context.save()
            if let cover { try? ImageStorageService().remove(cover) }
        } catch {
            context.rollback()
            self.error = error.localizedDescription
        }
    }
}
