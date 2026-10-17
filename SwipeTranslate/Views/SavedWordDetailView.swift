import SwiftUI
import SwiftData

struct SavedWordDetailView: View {
    let word: SavedWord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var translation = ""
    @State private var confirmingDelete = false
    @State private var error: String?
    @State private var saved = false

    var body: some View {
        Form {
            Section("Original · English") {
                Text(word.originalText).font(.system(.title, design: .serif)).textSelection(.enabled)
            }
            Section("Translation · Russian") {
                TextField("Russian translation", text: $translation, axis: .vertical).lineLimit(2...8)
                Button(saved ? "Changes Saved" : "Save Changes", systemImage: saved ? "checkmark" : "checkmark.circle") {
                    do { try VocabularyRepository(context: context).update(word, translation: translation); saved = true }
                    catch { self.error = error.localizedDescription }
                }.disabled(translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || translation == word.translatedText)
            }
            if let sentence = word.originalSentence, !sentence.isEmpty {
                Section("In context") { Text(sentence).font(.system(.body, design: .serif)).textSelection(.enabled) }
            }
            Section("Source") {
                LabeledContent("Book", value: word.book?.title ?? "Unknown book")
                LabeledContent("Saved", value: word.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            Section { Button("Delete Saved Entry", role: .destructive) { confirmingDelete = true } }
        }
        .navigationTitle("Saved Word").navigationBarTitleDisplayMode(.inline)
        .onAppear { translation = word.translatedText }
        .onChange(of: translation) { _, _ in saved = false }
        .confirmationDialog("Delete this saved entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Entry", role: .destructive) {
                do { try VocabularyRepository(context: context).delete(word); dismiss() }
                catch { self.error = error.localizedDescription }
            }
        }
        .alert("Couldn’t save changes", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}
