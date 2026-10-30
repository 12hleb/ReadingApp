import SwiftUI
import SwiftData
import Translation
import PhotosUI

struct CameraReaderView: View {
    let book: Book
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CameraReaderViewModel()
    @State private var choosingText = false
    @State private var showingPhotos = false
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                languageControls
                ZStack {
                    Color.black
                    if let frame = model.frozenFrame {
                        ZoomablePageView(frame: frame, selected: model.selection?.wordIDs ?? [],
                            onSelection: { model.select(anchor: $0, focus: $1, finished: $2) },
                            onClear: { model.clearSelection() })
                            .id(frame.id)
                            .allowsHitTesting(!model.isProcessing)
                    } else {
                        CameraPreview(session: model.camera.session)
                    }
                    if let activity = model.activity {
                        ProgressView(activity).padding().background(.regularMaterial, in: Capsule())
                    }
                    if !model.isFrozen && !model.isProcessing { cameraStatus }
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
                        Button("Choose from Photos", systemImage: "photo.on.rectangle") { showingPhotos = true }
                        Button("Try Sample Page", systemImage: "doc.text.viewfinder") {
                            Task { await model.loadSamplePage() }
                        }
                        if model.isFrozen {
                            Button("Choose Text", systemImage: "text.word.spacing") { choosingText = true }
                        }
                    } label: { Label("Reader Options", systemImage: "ellipsis.circle") }
                        .disabled(model.isProcessing)
                }
            }
            .task { await model.camera.start() }
            .photosPicker(isPresented: $showingPhotos, selection: $photo, matching: .images)
            .task(id: photo) {
                guard let photo else { return }
                await model.loadPhoto {
                    guard let data = try await photo.loadTransferable(type: Data.self) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    return data
                }
                guard !Task.isCancelled, self.photo == photo else { return }
                self.photo = nil // Permit selecting the same library image again.
            }
            .onChange(of: showingPhotos) { _, showing in
                if showing { model.camera.stop() }
                else { startCameraIfNeeded() }
            }
            .onChange(of: photo) { _, item in
                if item == nil { startCameraIfNeeded() }
            }
            .onChange(of: model.isProcessing) { _, processing in
                if !processing { startCameraIfNeeded() }
            }
            .onDisappear { model.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { model.camera.stop() }
                else { startCameraIfNeeded() }
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
        if model.isProcessing { return "Hold on while your photo is prepared" }
        if model.isFrozen {
            return model.frozenFrame?.page.words.isEmpty == false ? "Drag within one column · Pinch to zoom\nMove the photo with two fingers" : "No words found. Take a clearer photo or choose another image."
        }
        return "Photograph a page in \(model.translation.sourceLanguage.name) or choose one from Photos"
    }

    private var languageControls: some View {
        HStack {
            Picker("From", selection: Binding(
                get: { model.translation.sourceLanguage },
                set: { source in
                    let target = source == model.translation.targetLanguage
                        ? model.translation.sourceLanguage : model.translation.targetLanguage
                    Task { await model.setLanguages(source: source, target: target) }
                }
            )) {
                ForEach(ReaderLanguage.allCases) { Text($0.name).tag($0) }
            }.pickerStyle(.menu).accessibilityLabel("Photo language")
            Spacer(minLength: 8)
            Button {
                let source = model.translation.targetLanguage
                let target = model.translation.sourceLanguage
                Task { await model.setLanguages(source: source, target: target) }
            } label: { Image(systemName: "arrow.left.arrow.right") }
                .accessibilityLabel("Swap languages")
            Spacer(minLength: 8)
            Picker("To", selection: Binding(
                get: { model.translation.targetLanguage },
                set: { target in
                    let source = target == model.translation.sourceLanguage
                        ? model.translation.targetLanguage : model.translation.sourceLanguage
                    Task { await model.setLanguages(source: source, target: target) }
                }
            )) {
                ForEach(ReaderLanguage.allCases) { Text($0.name).tag($0) }
            }.pickerStyle(.menu).accessibilityLabel("Translation language")
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .disabled(model.isProcessing || showingPhotos)
    }

    private func startCameraIfNeeded() {
        guard scenePhase == .active, !showingPhotos, photo == nil,
              !model.isFrozen, !model.isProcessing else { return }
        Task { await model.camera.start() }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if model.isFrozen {
                    Button { Task { await model.resume() } } label: { Label("Retake", systemImage: "camera") }
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
                            .disabled(model.frozenFrame?.page.words.isEmpty != false)
                    }
                } else {
                    CameraLightButton(camera: model.camera)
                    Button { Task { await model.takePhoto() } } label: {
                        Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(model.camera.status != .running)
                }
            }.disabled(model.isProcessing)
            if let error = model.camera.lightError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            Button("Choose from Photos", systemImage: "photo.on.rectangle") { showingPhotos = true }
                .disabled(model.isProcessing)
            Text(model.isFrozen ? "\(model.frozenFrame?.page.words.count ?? 0) words detected · \(model.translation.languagePairLabel)" : "Word grid appears after you take a photo")
                .font(.caption).foregroundStyle(.secondary)
        }.padding()
    }

    @ViewBuilder private var cameraStatus: some View {
        switch model.camera.status {
        case .requesting:
            ProgressView("Starting camera…").padding().background(.regularMaterial, in: Capsule())
        case .denied:
            statusCard(title: "Camera access is off", message: "Allow camera access in Settings, or choose a page from Photos.", settings: true)
        case .unavailable:
            statusCard(title: "Camera unavailable", message: "Choose a page from Photos, or use the sample page.")
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
            Button("Try Sample Page") { Task { await model.loadSamplePage() } }.buttonStyle(.borderedProminent)
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

    private var columnWords: [OCRWord] {
        guard let word = page.words.first(where: { $0.id == first }) else { return [] }
        return page.words.filter { $0.columnIndex == word.columnIndex }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Choose the first and last word of a phrase in one column. For one word, choose it in both lists.") }
                Picker("First word", selection: $first) {
                    ForEach(page.words) { Text("\($0.id + 1). \($0.text)").tag($0.id) }
                }
                Picker("Last word", selection: $last) {
                    ForEach(columnWords) { Text("\($0.id + 1). \($0.text)").tag($0.id) }
                }
                .onChange(of: first) { _, _ in
                    if !columnWords.contains(where: { $0.id == last }) { last = first }
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
