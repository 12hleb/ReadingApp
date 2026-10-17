import SwiftUI
import SwiftData

@MainActor @Observable
final class CameraReaderViewModel {
    let camera = CameraService()
    let translation = TranslationService()
    var frozenFrame: CameraFrame?
    var selection: TextSelection?
    var showingTranslation = false
    var isLoadingFixture = false
    var error: String?
    var saveMessage: String?
    @ObservationIgnored private var fixtureTask: Task<Void, Never>?

    var frame: CameraFrame? { frozenFrame ?? camera.latestFrame }
    var isFrozen: Bool { frozenFrame != nil }

    func freeze() {
        guard let frame = camera.latestFrame else { return }
        // Freeze the exact image Vision analyzed, never a newer image paired with old boxes.
        frozenFrame = frame
        camera.stop()
        selection = nil
        translation.reset()
    }

    func resume() async {
        fixtureTask?.cancel()
        isLoadingFixture = false
        frozenFrame = nil
        camera.latestFrame = nil
        selection = nil
        saveMessage = nil
        showingTranslation = false
        translation.reset()
        await camera.retry()
    }

    func select(anchor: Int, focus: Int, finished: Bool) {
        guard let frame = frozenFrame else { return }
        let next = SelectionEngine.select(from: anchor, through: focus, page: frame.page)
        if next != selection {
            selection = next
            saveMessage = nil
            translation.reset() // Never leave a previous translation savable for new text.
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
        guard let selection, let result = translation.translatedText,
              translation.sourceText == selection.text else { return }
        do {
            let outcome = try VocabularyRepository(context: context).saveWord(original: selection.text,
                translation: result, sentence: selection.sentence, in: book)
            saveMessage = outcome.isDuplicate ? "Already in this book" : "Saved to \(book.title)"
        } catch { self.error = error.localizedDescription }
    }

    func loadSamplePage() {
        fixtureTask?.cancel()
        camera.stop()
        isLoadingFixture = true
        showingTranslation = false
        selection = nil
        translation.reset()
        fixtureTask = Task {
            defer { if !Task.isCancelled { isLoadingFixture = false } }
            guard let url = Bundle.main.url(forResource: "sample-page", withExtension: "png"),
                  let image = UIImage(contentsOfFile: url.path)?.cgImage else {
                error = "The bundled sample page is missing."; return
            }
            do {
                let page = try await Task.detached(priority: .userInitiated) { try OCRService.recognize(image) }.value
                guard !Task.isCancelled else { return }
                frozenFrame = CameraFrame(image: image, page: page)
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }

    func stop() { fixtureTask?.cancel(); camera.stop(); translation.reset() }
}
