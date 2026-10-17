import SwiftUI
import SwiftData
import AVFoundation

@MainActor @Observable
final class AddBookViewModel {
    var title = ""
    var cover: UIImage?
    var isRecognizing = false
    var isSaving = false
    var showingCamera = false
    var cameraDenied = false
    var error: String?
    var titleHint: String?
    @ObservationIgnored private var recognition: Task<Void, Never>?

    func requestCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            error = "A camera isn’t available. Choose a cover from Photos instead."
            return
        }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        else { allowed = status == .authorized }
        if allowed { showingCamera = true } else { cameraDenied = true }
    }

    func useCover(_ image: UIImage) {
        recognition?.cancel()
        let normalized = image.normalized()
        cover = normalized
        guard let pixels = normalized.cgImage else { return }
        isRecognizing = true
        titleHint = nil
        let previousTitle = title
        recognition = Task {
            do {
                let suggested = try await Task.detached(priority: .userInitiated) {
                    try OCRService.suggestTitle(in: pixels)
                }.value
                guard !Task.isCancelled else { return }
                if title == previousTitle { title = suggested.isEmpty ? previousTitle : suggested }
                titleHint = suggested.isEmpty ? "No title found. Please type it below." : "Suggested from your cover. Check the title before saving."
            } catch {
                guard !Task.isCancelled else { return }
                titleHint = "The cover is ready, but its title couldn’t be read. Please type it below."
            }
            isRecognizing = false
        }
    }

    func cancelRecognition() { recognition?.cancel() }

    func save(context: ModelContext) -> Bool {
        isSaving = true
        defer { isSaving = false }
        var path: String?
        do {
            if let cover { path = try ImageStorageService().save(cover) }
            try VocabularyRepository(context: context).createBook(title: title, coverPath: path)
            return true
        } catch {
            if let path { try? ImageStorageService().remove(path) }
            self.error = error.localizedDescription
            return false
        }
    }
}
