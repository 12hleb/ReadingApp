import SwiftUI
import SwiftData

@MainActor @Observable
final class CameraReaderViewModel {
    let camera = CameraService()
    let translation = TranslationService()
    private(set) var frozenFrame: CameraFrame?
    var selection: TextSelection?
    var showingTranslation = false
    private(set) var activity: String?
    var error: String?
    var saveMessage: String?
    @ObservationIgnored private var operationID = UUID()
    @ObservationIgnored private let recognize: @Sendable (CGImage, ReaderLanguage) throws -> OCRPage

    init(recognize: @escaping @Sendable (CGImage, ReaderLanguage) throws -> OCRPage = {
        try OCRService.recognize($0, language: $1)
    }) {
        self.recognize = recognize
    }

    var isFrozen: Bool { frozenFrame != nil }
    var isProcessing: Bool { activity != nil }

    func setLanguages(source: ReaderLanguage, target: ReaderLanguage) async {
        guard !isProcessing, source != target,
              source != translation.sourceLanguage || target != translation.targetLanguage else { return }
        let sourceChanged = source != translation.sourceLanguage
        translation.setLanguages(source: source, target: target)
        saveMessage = nil
        guard sourceChanged else {
            if let selection { translation.request(selection.text) }
            return
        }

        clearSelection()
        showingTranslation = false
        guard let image = frozenFrame?.image else { return }
        let id = beginOperation("Finding \(source.name) words…")
        // Hide old-language boxes immediately, including when recognition fails.
        frozenFrame = CameraFrame(image: image, page: .empty)
        let recognize = recognize
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let page = try recognize(image, source)
            try Task.checkCancellation()
            return CameraFrame(image: image, page: page)
        }
        do {
            let frame = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            if operationID == id, !Task.isCancelled { frozenFrame = frame }
        } catch { handle(error, operation: id) }
        finishOperation(id)
    }

    func takePhoto() async {
        guard !isProcessing else { return }
        let id = beginOperation("Taking photo…")
        do {
            let data = try await camera.capturePhoto()
            guard operationID == id, !Task.isCancelled else { finishOperation(id); return }
            camera.stop()
            activity = "Finding words…"
            try await recognizePhoto(data, operation: id)
        } catch { handle(error, operation: id) }
        finishOperation(id)
    }

    /// PhotosPicker may download an iCloud image. Keep loading and OCR in the same
    /// operation so a late download cannot replace a newer photo or a closed reader.
    func loadPhoto(using loadData: () async throws -> Data) async {
        let id = beginOperation("Loading photo…")
        camera.stop()
        do {
            let data = try await loadData()
            try Task.checkCancellation()
            guard operationID == id else { return }
            activity = "Finding words…"
            try await recognizePhoto(data, operation: id)
        } catch { handle(error, operation: id) }
        finishOperation(id)
    }

    func loadSamplePage() async {
        // The bundled sample is English. Keep a different target when switching to it.
        let target: ReaderLanguage = translation.targetLanguage == .english ? .russian : translation.targetLanguage
        translation.setLanguages(source: .english, target: target)
        await loadPhoto {
            guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "png") else {
                throw CocoaError(.fileNoSuchFile)
            }
            return try Data(contentsOf: url)
        }
    }

    private func beginOperation(_ message: String) -> UUID {
        operationID = UUID()
        activity = message
        error = nil
        clearSelection()
        showingTranslation = false
        return operationID
    }

    private func recognizePhoto(_ data: Data, operation id: UUID) async throws {
        let recognize = recognize
        let language = translation.sourceLanguage
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let image = try ReaderImageDecoder.decode(data)
            let page = try recognize(image, language)
            try Task.checkCancellation()
            return CameraFrame(image: image, page: page)
        }
        let frame = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: { task.cancel() }
        guard operationID == id, !Task.isCancelled else { return }
        frozenFrame = frame
    }

    private func handle(_ error: Error, operation id: UUID) {
        guard operationID == id else { return }
        if !(error is CancellationError), !Task.isCancelled {
            self.error = "The photo couldn’t be read. Try taking another photo or choosing a different image. \(error.localizedDescription)"
        }
    }

    private func finishOperation(_ id: UUID) {
        if operationID == id { activity = nil }
    }

    func resume() async {
        stop()
        frozenFrame = nil
        clearSelection()
        showingTranslation = false
        await camera.retry()
    }

    func select(anchor: Int, focus: Int, finished: Bool) {
        guard !isProcessing, let frame = frozenFrame else { return }
        let next = SelectionEngine.select(from: anchor, through: focus, page: frame.page)
        if next != selection {
            selection = next
            saveMessage = nil
            translation.reset()
        }
        if finished, let selection {
            translation.request(selection.text)
            showingTranslation = true
        }
    }

    func clearSelection() {
        selection = nil
        saveMessage = nil
        translation.reset()
    }

    func save(in book: Book, context: ModelContext) {
        guard !isProcessing, let selection, let result = translation.translatedText,
              translation.sourceText == selection.text else { return }
        do {
            let outcome = try VocabularyRepository(context: context).saveWord(original: selection.text,
                translation: result, sentence: selection.sentence, in: book,
                sourceLanguage: translation.sourceLanguage, targetLanguage: translation.targetLanguage)
            saveMessage = outcome.isDuplicate ? "Already in this book" : "Saved to \(book.title)"
        } catch { self.error = error.localizedDescription }
    }

    func stop() {
        operationID = UUID()
        activity = nil
        camera.stop()
        translation.reset()
    }
}
