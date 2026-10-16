import Vision
import NaturalLanguage
import CoreGraphics
import ImageIO

enum ReaderImageDecoder {
    /// Downsample before decoding large camera/library images. Apply EXIF rotation
    /// once so the displayed photo and Vision's word boxes use identical pixels.
    static func decode(_ data: Data, maxDimension: Int = 4096) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        return image
    }
}

enum OCRService {
    static func recognize(_ image: CGImage, accurate: Bool = true, language: ReaderLanguage = .english) throws -> OCRPage {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = accurate ? .accurate : .fast
        request.recognitionLanguages = [language.recognitionIdentifier]
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.008
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        let lines: [RecognizedLine] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first, candidate.confidence >= 0.25 else { return nil }
            let text = candidate.string
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = text
            tokenizer.setLanguage(NLLanguage(rawValue: language.rawValue))
            var tokens: [RecognizedToken] = []
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                // Some Vision revisions cannot resolve a particular word. Skip that word
                // instead of inventing a character-proportional rectangle.
                if let box = try? candidate.boundingBox(for: range) {
                    tokens.append(RecognizedToken(text: String(text[range]), bounds: box.boundingBox,
                                                  range: NSRange(range, in: text)))
                }
                return true
            }
            return RecognizedLine(text: text, bounds: observation.boundingBox, tokens: tokens)
        }
        return OCRResultProcessor.assemble(lines) { text in
            // Treat printed line wraps as spaces for sentence segmentation. A newline
            // and a space occupy the same UTF-16 length, preserving all word offsets.
            let continuousText = text.replacingOccurrences(of: "\n", with: " ")
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = continuousText
            tokenizer.setLanguage(NLLanguage(rawValue: language.rawValue))
            var ranges: [NSRange] = []
            tokenizer.enumerateTokens(in: continuousText.startIndex..<continuousText.endIndex) { range, _ in
                ranges.append(NSRange(range, in: continuousText)); return true
            }
            return ranges
        }
    }

    static func suggestTitle(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ReaderLanguage.allCases.map(\.recognitionIdentifier)
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        let candidates = (request.results ?? []).filter { ($0.topCandidates(1).first?.confidence ?? 0) >= 0.3 }
        guard let largest = candidates.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else { return "" }
        // A title often spans several similarly large adjacent lines. This remains an editable suggestion.
        return candidates.filter {
            $0.boundingBox.height >= largest.boundingBox.height * 0.7 &&
            abs($0.boundingBox.midY - largest.boundingBox.midY) <= largest.boundingBox.height * 3
        }.sorted { $0.boundingBox.midY > $1.boundingBox.midY }.prefix(3)
            .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }
}
