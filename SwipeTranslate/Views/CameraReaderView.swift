import SwiftUI
import SwiftData
import Translation

struct CameraReaderView: View {
    let book: Book
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CameraReaderViewModel()
    @State private var choosingText = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black
                    if let frame = model.frozenFrame {
                        GeometryReader { proxy in
                            Image(decorative: frame.image, scale: 1)
                                .resizable().scaledToFit().frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    } else {
                        CameraPreview(session: model.camera.session)
                    }
                    if let frame = model.frame {
                        TextSelectionOverlay(page: frame.page, imageSize: frame.size,
                            isFrozen: model.isFrozen, selected: model.selection?.wordIDs ?? [],
                            onSelection: { model.select(anchor: $0, focus: $1, finished: $2) },
                            onClear: { model.clearSelection() })
                    }
                    if model.isLoadingFixture { ProgressView("Reading sample page…").padding().background(.regularMaterial, in: Capsule()) }
                    if !model.isFrozen && !model.isLoadingFixture { cameraStatus }
                    VStack {
                        Text(hint).font(.caption.weight(.medium)).multilineTextAlignment(.center)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.regularMaterial, in: Capsule()).padding()
                            .allowsHitTesting(false)
                        Spacer()
                    }.allowsHitTesting(false)
                }.clipped()
                controls
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(model.isFrozen ? "Select Text" : "Camera Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Try Sample Page", systemImage: "doc.text.viewfinder") { model.loadSamplePage() }
                        if model.isFrozen {
                            Button("Choose Text", systemImage: "text.word.spacing") { choosingText = true }
                        }
                    } label: { Label("Reader Options", systemImage: "ellipsis.circle") }
                }
            }
            .task { await model.camera.start() }
            .onDisappear { model.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.camera.stop() }
                else if !model.isFrozen && !model.isLoadingFixture { Task { await model.camera.start() } }
            }
            .translationTask(model.translation.configuration) { session in
                await model.translation.translate(using: session)
            }
            .sheet(isPresented: $model.showingTranslation) {
                TranslationPanelView(model: model, book: book) { model.save(in: book, context: context) }
            }
            .sheet(isPresented: $choosingText) {
                if let page = model.frozenFrame?.page {
                    AccessibleSelectionView(page: page) { first, last in
                        model.select(anchor: first, focus: last, finished: false)
                        choosingText = false
                    }
                }
            }
            .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }

    private var hint: String {
        if model.isFrozen {
            return model.frame?.page.words.isEmpty == false ? "Tap a word or drag across a phrase" : "No text found. Scan again in brighter light."
        }
        if let warning = model.camera.ocrWarning { return warning }
        return model.frame?.page.words.isEmpty == false ? "Hold steady, then freeze the page" : "Point at a well-lit English book page"
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if model.isFrozen {
                    Button { Task { await model.resume() } } label: { Label("Scan Again", systemImage: "camera") }
                        .buttonStyle(.bordered).controlSize(.large)
                    if let selection = model.selection {
                        Button {
                            model.translation.request(selection.text)
                            model.showingTranslation = true
                        } label: { Label("Translate", systemImage: "character.bubble") }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    } else {
                        Button("Choose Text", systemImage: "text.cursor") { choosingText = true }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(model.frame?.page.words.isEmpty != false)
                    }
                } else {
                    Button { model.freeze() } label: {
                        Label("Freeze Page", systemImage: "viewfinder").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(model.camera.latestFrame == nil || model.camera.status != .running || model.isLoadingFixture)
                }
            }
            Text(model.isFrozen ? "Frozen page · \(model.frame?.page.words.count ?? 0) words detected" : "English → Russian · On-device translation")
                .font(.caption).foregroundStyle(.secondary)
        }.padding()
    }

    @ViewBuilder private var cameraStatus: some View {
        switch model.camera.status {
        case .requesting:
            ProgressView("Starting camera…").padding().background(.regularMaterial, in: Capsule())
        case .denied:
            statusCard(title: "Camera access is off", message: "Allow camera access in Settings, or explore the sample page.", settings: true)
        case .unavailable:
            statusCard(title: "Camera unavailable", message: "Use a physical iPhone for live reading. You can test selection with the sample page.")
        case .failed(let message), .interrupted(let message):
            statusCard(title: "Camera paused", message: message)
        default: EmptyView()
        }
    }

    private func statusCard(title: String, message: String, settings: Bool = false) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera").font(.largeTitle)
            Text(title).font(.headline)
            Text(message).font(.subheadline).multilineTextAlignment(.center)
            if settings {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
            } else { Button("Retry") { Task { await model.camera.retry() } } }
            Button("Try Sample Page") { model.loadSamplePage() }.buttonStyle(.borderedProminent)
        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22)).padding(28)
    }
}

/// VoiceOver and large-type alternative to spatial gestures. Choose the start and end
/// words in reading order, then use the reader's Translate button.
private struct AccessibleSelectionView: View {
    let page: OCRPage
    let onSelect: (Int, Int) -> Void
    @State private var first = 0
    @State private var last = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Choose the first and last word of a phrase. For one word, choose it in both lists.") }
                Picker("First word", selection: $first) {
                    ForEach(page.words) { Text("\($0.id + 1). \($0.text)").tag($0.id) }
                }
                Picker("Last word", selection: $last) {
                    ForEach(page.words) { Text("\($0.id + 1). \($0.text)").tag($0.id) }
                }
                if let selection = SelectionEngine.select(from: first, through: last, page: page) {
                    Section("Selected text") { Text(selection.text) }
                }
                Button("Use Selection") { onSelect(first, last) }.disabled(page.words.isEmpty)
            }.navigationTitle("Choose Text").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
