import Foundation
import CoreGraphics

struct OCRWord: Identifiable, Equatable {
    let id: Int
    let text: String
    /// Vision coordinates: normalized, origin at bottom left of upright pixels.
    let bounds: CGRect
    let range: NSRange
    let lineIndex: Int
}

struct OCRPage {
    let text: String
    let words: [OCRWord]
    let sentenceRanges: [NSRange]
    static let empty = OCRPage(text: "", words: [], sentenceRanges: [])
}

struct RecognizedLine {
    let text: String
    let bounds: CGRect
    let tokens: [RecognizedToken]
}

struct RecognizedToken {
    let text: String
    let bounds: CGRect
    let range: NSRange
}

enum OCRResultProcessor {
    /// Cluster baseline neighbors before sorting horizontally. This avoids a non-transitive
    /// comparator when the printed page is slightly skewed. MVP expects a single text column.
    static func readingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        var rows: [[RecognizedLine]] = []
        for line in lines.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
            if let index = rows.firstIndex(where: { row in
                guard let first = row.first else { return false }
                return abs(first.bounds.midY - line.bounds.midY) < min(first.bounds.height, line.bounds.height) * 0.5
            }) {
                rows[index].append(line)
            } else { rows.append([line]) }
        }
        return rows.flatMap { $0.sorted { $0.bounds.minX < $1.bounds.minX } }
    }

    static func assemble(_ lines: [RecognizedLine], sentences: (String) -> [NSRange]) -> OCRPage {
        var text = ""
        var words: [OCRWord] = []
        for (lineIndex, line) in readingOrder(lines).enumerated() {
            if !text.isEmpty { text += "\n" }
            let offset = (text as NSString).length
            text += line.text
            for token in line.tokens.sorted(by: { $0.range.location < $1.range.location }) {
                words.append(OCRWord(id: words.count, text: token.text, bounds: token.bounds,
                    range: NSRange(location: offset + token.range.location, length: token.range.length), lineIndex: lineIndex))
            }
        }
        return OCRPage(text: text, words: words, sentenceRanges: sentences(text))
    }
}
