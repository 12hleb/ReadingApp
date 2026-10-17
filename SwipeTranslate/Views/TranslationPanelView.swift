import SwiftUI

struct TranslationPanelView: View {
    let model: CameraReaderViewModel
    let book: Book
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("English → Russian", systemImage: "character.bubble").font(.subheadline.weight(.medium))
                    Spacer()
                    Button("Close", systemImage: "xmark.circle.fill") { dismiss() }
                        .labelStyle(.iconOnly).font(.title3).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("ORIGINAL TEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(model.selection?.text ?? "Select a word on the page")
                        .font(.system(.title2, design: .serif)).textSelection(.enabled)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("RUSSIAN TRANSLATION").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    switch model.translation.state {
                    case .idle:
                        Text("Select text to translate.").foregroundStyle(.secondary)
                    case .loading:
                        ProgressView("Translating…")
                        Text("If prompted, download the English and Russian languages.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .translated(let text):
                        Text(text).font(.title2).textSelection(.enabled)
                    case .failed(let message):
                        Text(message).font(.subheadline).foregroundStyle(.secondary)
                        Button("Try Again", systemImage: "arrow.clockwise") {
                            if let selection = model.selection { model.translation.request(selection.text, force: true) }
                        }
                    }
                }
                Button(action: onSave) {
                    Label(model.saveMessage == nil ? "Save to Book" : "Saved in Book", systemImage: model.saveMessage == nil ? "bookmark.fill" : "checkmark")
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                }.buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(model.translation.translatedText == nil || model.translation.sourceText != model.selection?.text || model.saveMessage != nil)
                if let message = model.saveMessage { Text(message).font(.caption).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
                if let sentence = model.selection?.sentence {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("IN CONTEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(sentence).font(.system(.body, design: .serif)).foregroundStyle(.secondary)
                    }
                }
                Text("Saving to \(book.title)").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
        .presentationDetents([.height(300), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
    }
}
