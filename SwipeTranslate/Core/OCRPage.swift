import Foundation
import CoreGraphics

struct OCRWord: Identifiable, Equatable {
    let id: Int
    let text: String
    /// Vision coordinates: normalized, origin at bottom left of upright pixels.
    let bounds: CGRect
    let range: NSRange
    let lineIndex: Int
    var columnIndex: Int = 0
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
    /// Group nearby baselines before sorting horizontally, including slightly skewed photos.
    private static func rows(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        var rows: [[RecognizedLine]] = []
        for line in lines.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
            if let index = rows.firstIndex(where: { row in
                guard let first = row.first else { return false }
                return abs(first.bounds.midY - line.bounds.midY) < min(first.bounds.height, line.bounds.height) * 0.5
            }) {
                rows[index].append(line)
            } else { rows.append([line]) }
        }
        return rows.map { $0.sorted { $0.bounds.minX < $1.bounds.minX } }
    }

    static func readingOrder(_ lines: [RecognizedLine]) -> [RecognizedLine] {
        columns(lines).flatMap { rows($0).flatMap { $0 } }
    }

    private struct Gutter {
        let left: CGFloat
        let right: CGFloat
        let row: Int
        func contains(_ x: CGFloat) -> Bool { left < x && x < right }
    }

    /// Repeated wide whitespace between text on the same baselines identifies
    /// column gutters. A heading may cross a gutter, but ordinary word spaces
    /// must not divide the page into columns.
    private static func columns(_ lines: [RecognizedLine]) -> [[RecognizedLine]] {
        guard !lines.isEmpty else { return [] }
        let characterWidths = lines.flatMap(\.tokens).filter { $0.text.count >= 2 && $0.bounds.width > 0 }
            .map { $0.bounds.width / CGFloat($0.text.count) }.sorted()
        let characterWidth = characterWidths.isEmpty ? CGFloat(0.004) : characterWidths[characterWidths.count / 2]
        let minimumGap = max(0.012, characterWidth * 2.5)
        let rowBoxes = rows(lines).map { row in
            row.flatMap { line in line.tokens.isEmpty ? [line.bounds] : line.tokens.map(\.bounds) }
                .sorted { $0.minX < $1.minX }
        }
        var gaps: [Gutter] = []
        for (row, boxes) in rowBoxes.enumerated() {
            guard let first = boxes.first else { continue }
            var right = first.maxX
            for box in boxes.dropFirst() {
                if box.minX - right >= minimumGap {
                    gaps.append(Gutter(left: right, right: box.minX, row: row))
                }
                right = max(right, box.maxX)
            }
        }
        let minimumRows = max(3, Int(ceil(Double(rowBoxes.count) * 0.25)))
        var cuts: [CGFloat] = []
        while !gaps.isEmpty {
            var bestX: CGFloat?
            var bestSupport = 0
            var bestWidth: CGFloat = 0
            for candidate in gaps {
                let x = (candidate.left + candidate.right) / 2
                let matching = gaps.filter { $0.contains(x) }
                let support = Set(matching.map(\.row)).count
                guard support >= minimumRows else { continue }
                let crossings = rowBoxes.filter { $0.contains { $0.minX < x && $0.maxX > x } }.count
                guard crossings <= max(1, support / 4) else { continue }
                let left = matching.map(\.left).max() ?? candidate.left
                let right = matching.map(\.right).min() ?? candidate.right
                if support > bestSupport || (support == bestSupport && right - left > bestWidth) {
                    bestSupport = support
                    bestWidth = right - left
                    bestX = (left + right) / 2
                }
            }
            guard let x = bestX else { break }
            cuts.append(x)
            gaps.removeAll { $0.contains(x) }
        }
        guard !cuts.isEmpty else { return [lines] }
        cuts.sort()
        var groups = Array(repeating: [RecognizedLine](), count: cuts.count + 1)
        var spanning: [RecognizedLine] = []
        for line in lines {
            let crossed = cuts.filter { line.bounds.minX < $0 && $0 < line.bounds.maxX }
            if crossed.isEmpty {
                groups[cuts.filter { $0 < line.bounds.midX }.count].append(line)
                continue
            }
            // Vision can combine two columns into one observation. Split it only
            // where the actual word boxes leave a gutter; keep full-width headings separate.
            let tokens = line.tokens.sorted { $0.range.location < $1.range.location }
            let canSplit = !tokens.isEmpty && crossed.allSatisfy { x in
                guard !tokens.contains(where: { $0.bounds.minX < x && $0.bounds.maxX > x }),
                      let left = tokens.filter({ $0.bounds.midX < x }).map({ $0.bounds.maxX }).max(),
                      let right = tokens.filter({ $0.bounds.midX > x }).map({ $0.bounds.minX }).min() else { return false }
                return right - left >= minimumGap
            }
            guard canSplit else { spanning.append(line); continue }
            let source = line.text as NSString
            var runs: [(column: Int, tokens: [RecognizedToken])] = []
            for token in tokens {
                let column = cuts.filter { $0 < token.bounds.midX }.count
                if runs.last?.column == column { runs[runs.count - 1].tokens.append(token) }
                else { runs.append((column, [token])) }
            }
            for (index, run) in runs.enumerated() {
                let start = index == 0 ? 0 : run.tokens[0].range.location
                let end = index + 1 < runs.count ? runs[index + 1].tokens[0].range.location : source.length
                guard start >= 0, end >= start, end <= source.length else { continue }
                let adjusted = run.tokens.map {
                    RecognizedToken(text: $0.text, bounds: $0.bounds,
                        range: NSRange(location: $0.range.location - start, length: $0.range.length))
                }
                let bounds = run.tokens.dropFirst().reduce(run.tokens[0].bounds) { $0.union($1.bounds) }
                groups[run.column].append(RecognizedLine(text: source.substring(with: NSRange(location: start, length: end - start)),
                    bounds: bounds, tokens: adjusted))
            }
        }
        return (spanning.isEmpty ? [] : [spanning]) + groups.filter { !$0.isEmpty }
    }

    static func assemble(_ lines: [RecognizedLine], sentences: (String) -> [NSRange]) -> OCRPage {
        var text = ""
        var words: [OCRWord] = []
        var sentenceRanges: [NSRange] = []
        var lineIndex = 0
        for (columnIndex, column) in columns(lines).enumerated() {
            if !text.isEmpty { text += "\n" }
            let columnOffset = (text as NSString).length
            var columnText = ""
            for line in rows(column).flatMap({ $0 }) {
                if !columnText.isEmpty { columnText += "\n" }
                let offset = columnOffset + (columnText as NSString).length
                columnText += line.text
                for token in line.tokens.sorted(by: { $0.range.location < $1.range.location }) {
                    words.append(OCRWord(id: words.count, text: token.text, bounds: token.bounds,
                        range: NSRange(location: offset + token.range.location, length: token.range.length),
                        lineIndex: lineIndex, columnIndex: columnIndex))
                }
                lineIndex += 1
            }
            // Sentence context must never join the end of one column to the next.
            sentenceRanges += sentences(columnText).map {
                NSRange(location: columnOffset + $0.location, length: $0.length)
            }
            text += columnText
        }
        return OCRPage(text: text, words: words, sentenceRanges: sentenceRanges)
    }
}
