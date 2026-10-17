import SwiftUI
import SwiftData

struct BookAlbumView: View {
    let book: Book
    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var showingReader = false
    @State private var error: String?

    private var words: [SavedWord] {
        book.savedWords.filter {
            search.isEmpty || $0.originalText.localizedStandardContains(search) ||
                $0.translatedText.localizedStandardContains(search) || ($0.originalSentence?.localizedStandardContains(search) ?? false)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 20) {
                    BookCover(book: book, width: 82)
                    VStack(alignment: .leading, spacing: 9) {
                        Text(book.title).font(.system(.title2, design: .serif).weight(.semibold))
                        Text("\(book.savedWords.count) saved entries").foregroundStyle(.secondary).font(.subheadline)
                        Text("A little more fluent, page by page.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
                Button {
                    book.lastReadAt = .now
                    do { try context.save(); showingReader = true }
                    catch { context.rollback(); self.error = error.localizedDescription }
                } label: {
                    Label("Start Reading", systemImage: "viewfinder").frame(maxWidth: .infinity).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }
            Section("Vocabulary") {
                if words.isEmpty {
                    ContentUnavailableView {
                        Label(search.isEmpty ? "Words worth keeping" : "No matching words", systemImage: search.isEmpty ? "bookmark" : "magnifyingglass")
                    } description: {
                        Text(search.isEmpty ? "Scan a page and save a word or phrase. It will be waiting here next time." : "Try an English word, Russian translation, or part of a sentence.")
                    }
                }
                ForEach(words) { word in
                    NavigationLink { SavedWordDetailView(word: word) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(word.originalText).font(.system(.headline, design: .serif))
                            Text(word.translatedText).foregroundStyle(.secondary)
                            if let sentence = word.originalSentence {
                                Text(sentence).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Text(word.createdAt, format: .dateTime.month(.abbreviated).day()).font(.caption2).foregroundStyle(.tertiary)
                        }.padding(.vertical, 5)
                    }.swipeActions {
                        Button("Delete", role: .destructive) {
                            do { try VocabularyRepository(context: context).delete(word) }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .navigationTitle("Book Album").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search saved vocabulary")
        .fullScreenCover(isPresented: $showingReader) { CameraReaderView(book: book) }
        .alert("Couldn’t update your book", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}
