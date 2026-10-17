import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]
    @State private var model = LibraryViewModel()
    @State private var bookToDelete: Book?

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("A new chapter starts here", systemImage: "books.vertical")
                    } description: {
                        Text("Add a book, scan a page, and make unfamiliar English words part of your Russian vocabulary.")
                    } actions: {
                        Button("Add Your First Book", systemImage: "plus") { model.showingAddBook = true }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    }
                } else {
                    List {
                        Section {
                            ForEach(books) { book in
                                NavigationLink { BookAlbumView(book: book) } label: { BookAlbumRow(book: book) }
                                    .swipeActions {
                                        Button("Delete", role: .destructive) { bookToDelete = book }
                                    }
                            }
                        } header: {
                            Text("Your books · Your words").textCase(nil)
                        }
                    }
                }
            }
            .navigationTitle("My Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Book", systemImage: "plus") { model.showingAddBook = true }
                }
            }
            .sheet(isPresented: $model.showingAddBook) { AddBookView() }
            .confirmationDialog("Delete this book and all its saved vocabulary?", isPresented: Binding(
                get: { bookToDelete != nil }, set: { if !$0 { bookToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete Book", role: .destructive) {
                    if let bookToDelete { model.delete(bookToDelete, context: context) }
                    bookToDelete = nil
                }
            }
            .alert("Couldn’t update your library", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }
}

#Preview { LibraryView().modelContainer(PreviewData.container) }
