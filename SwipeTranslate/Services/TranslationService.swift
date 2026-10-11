import Foundation
import Observation
import Translation

enum ReaderLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en", russian = "ru", spanish = "es"
    var id: String { rawValue }
    var name: String {
        switch self {
        case .english: "English"
        case .russian: "Russian"
        case .spanish: "Spanish"
        }
    }
    var recognitionIdentifier: String {
        switch self {
        case .english: "en-US"
        case .russian: "ru-RU"
        case .spanish: "es-ES"
        }
    }
    var localeLanguage: Locale.Language { Locale.Language(identifier: rawValue) }
}

enum TranslationState: Equatable {
    case idle
    case loading
    case translated(String)
    case failed(String)
}

@MainActor @Observable
final class TranslationService {
    private(set) var configuration: TranslationSession.Configuration?
    private(set) var state: TranslationState = .idle
    private(set) var sourceText = ""
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var cache: [CacheKey: String] = [:]
    @ObservationIgnored private var cacheOrder: [CacheKey] = []
    private(set) var sourceLanguage: ReaderLanguage = .english
    private(set) var targetLanguage: ReaderLanguage = .russian
    var languagePairLabel: String { "\(sourceLanguage.name) → \(targetLanguage.name)" }

    private struct CacheKey: Hashable {
        let text: String
        let source: ReaderLanguage
        let target: ReaderLanguage
    }

    func setLanguages(source: ReaderLanguage, target: ReaderLanguage) {
        guard source != target, source != sourceLanguage || target != targetLanguage else { return }
        reset()
        sourceLanguage = source
        targetLanguage = target
    }

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
        let key = CacheKey(text: text, source: sourceLanguage, target: targetLanguage)
        if !force, let cached = cache[key] { state = .translated(cached); return }
        state = .loading
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: sourceLanguage.localeLanguage, target: targetLanguage.localeLanguage)
        } else {
            configuration?.source = sourceLanguage.localeLanguage
            configuration?.target = targetLanguage.localeLanguage
            configuration?.invalidate()
        }
    }

    func reset() {
        requestID = UUID()
        sourceText = ""
        state = .idle
        // Keep the configuration's version across selection changes. Resetting it
        // to nil and recreating it can happen before SwiftUI updates, leaving an
        // equal configuration and no new translationTask. request() invalidates
        // this existing configuration to reliably start the next translation.
    }

    /// Called only by SwiftUI's translationTask. Apple owns the session and model-download UI.
    func translate(using session: TranslationSession) async {
        guard case .loading = state else { return }
        let id = requestID
        let text = sourceText
        let source = sourceLanguage
        let target = targetLanguage
        let key = CacheKey(text: text, source: source, target: target)
        do {
            let availability = await LanguageAvailability().status(from: source.localeLanguage, to: target.localeLanguage)
            try Task.checkCancellation()
            guard id == requestID else { return }
            guard availability != .unsupported else {
                state = .failed("\(source.name)-to-\(target.name) translation isn’t available on this device.")
                return
            }
            // If needed, the OS asks permission to download language resources. Text and
            // book photographs never go to an app-operated service.
            try await session.prepareTranslation()
            try Task.checkCancellation()
            guard id == requestID else { return }
            let response = try await session.translate(text)
            try Task.checkCancellation()
            guard id == requestID else { return }
            let result = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !result.isEmpty else { throw TranslationFailure.emptyResult }
            cache[key] = result
            cacheOrder.removeAll { $0 == key }
            cacheOrder.append(key)
            if cacheOrder.count > 100 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
            state = .translated(result)
        } catch is CancellationError {
            guard id == requestID else { return }
            state = .failed("Translation was interrupted. Please try again.")
        } catch {
            guard id == requestID else { return }
            state = .failed("Translation couldn’t finish. If asked, allow the \(source.name) and \(target.name) language downloads, then try again. \(error.localizedDescription)")
        }
    }

    private enum TranslationFailure: Error { case emptyResult }
}
