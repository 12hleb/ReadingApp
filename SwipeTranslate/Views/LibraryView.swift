import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var model = LibraryViewModel()
    @State private var openBookID: UUID?
    @State private var selectedBook: Book?

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("A new chapter starts here", systemImage: "books.vertical")
                    } description: {
                        Text("Add a book, scan a page, and build your vocabulary in English, Russian, or Spanish.")
                    } actions: {
                        Button("Add Your First Book", systemImage: "plus") { model.showingAddBook = true }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                } else {
                    List {
                        Section {
                            ForEach(books) { book in
                                SwipeableBookRow(book: book, openBookID: $openBookID) {
                                    openBookID = nil
                                    selectedBook = book
                                } onDelete: {
                                    openBookID = nil
                                    model.delete(book, context: context)
                                }
                            }
                        } header: {
                            Text("Your books · Your words").textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("My Library")
            .navigationDestination(item: $selectedBook) { book in BookAlbumView(book: book) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Book", systemImage: "plus") {
                        openBookID = nil
                        model.showingAddBook = true
                    }
                }
            }
            .sheet(isPresented: $model.showingAddBook) { AddBookView() }
            .alert("Couldn’t update your library", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }
}

#Preview { LibraryView().modelContainer(PreviewData.container) }
