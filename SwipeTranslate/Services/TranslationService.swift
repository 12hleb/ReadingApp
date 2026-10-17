import Foundation
import Observation
import Translation

enum TranslationState: Equatable {
    case idle
    case loading
    case translated(String)
    case failed(String)
}

@MainActor @Observable
final class TranslationService {
    var configuration: TranslationSession.Configuration?
    private(set) var state: TranslationState = .idle
    private(set) var sourceText = ""
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var cache: [String: String] = [:]
    @ObservationIgnored private var cacheOrder: [String] = []
    private let source = Locale.Language(identifier: "en")
    private let target = Locale.Language(identifier: "ru")

    var translatedText: String? {
        if case .translated(let value) = state { return value }
        return nil
    }

    func request(_ text: String, force: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { reset(); return }
        if !force, sourceText == text {
            switch state { case .loading, .translated: return; default: break }
        }
        requestID = UUID()
        sourceText = text
        if !force, let cached = cache[text] { state = .translated(cached); return }
        state = .loading
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: source, target: target)
        } else { configuration?.invalidate() }
    }

    func reset() {
        requestID = UUID()
        sourceText = ""
        state = .idle
        configuration = nil
    }

    /// Called only by SwiftUI's translationTask. Apple owns the session and model-download UI.
    func translate(using session: TranslationSession) async {
        guard case .loading = state else { return }
        let id = requestID
        let text = sourceText
        do {
            let availability = await LanguageAvailability().status(from: source, to: target)
            guard id == requestID, !Task.isCancelled else { return }
            guard availability != .unsupported else {
                state = .failed("English-to-Russian translation isn’t available on this device.")
                return
            }
            // If needed, the OS asks permission to download language resources. Text and
            // book photographs never go to an app-operated service.
            try await session.prepareTranslation()
            try Task.checkCancellation()
            guard id == requestID else { return }
            let response = try await session.translate(text)
            guard id == requestID, !Task.isCancelled else { return }
            let result = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else { throw TranslationFailure.emptyResult }
            cache[text] = result
            cacheOrder.removeAll { $0 == text }
            cacheOrder.append(text)
            if cacheOrder.count > 100 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
            state = .translated(result)
        } catch {
            guard id == requestID else { return }
            state = .failed("Translation couldn’t finish. If asked, allow the English and Russian language downloads, then try again. \(error.localizedDescription)")
        }
    }

    private enum TranslationFailure: Error { case emptyResult }
}
