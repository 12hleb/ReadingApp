import XCTest
@testable import SwipeTranslate

final class SelectionTests: XCTestCase {
    private func page() -> OCRPage {
        let first = "A quiet garden waits."
        let second = "A new chapter begins."
        func line(_ text: String, y: CGFloat) -> RecognizedLine {
            let ns = text as NSString
            let tokens = text.split(separator: " ").enumerated().map { index, raw in
                let word = String(raw).trimmingCharacters(in: .punctuationCharacters)
                // Search from the current cursor to account for repeated words.
                let start = text.split(separator: " ").prefix(index).map { $0.utf16.count + 1 }.reduce(0, +)
                return RecognizedToken(text: word, bounds: CGRect(x: 0.1 + Double(index) * 0.18, y: y, width: 0.15, height: 0.05),
                                       range: ns.range(of: word, range: NSRange(location: start, length: ns.length - start)))
            }
            return RecognizedLine(text: text, bounds: CGRect(x: 0.1, y: y, width: 0.8, height: 0.05), tokens: tokens)
        }
        return OCRResultProcessor.assemble([line(second, y: 0.6), line(first, y: 0.8)]) { _ in
            [NSRange(location: 0, length: first.utf16.count), NSRange(location: first.utf16.count + 1, length: second.utf16.count)]
        }
    }

    func testSingleWordKeepsSurroundingSentence() throws {
        let selected = try XCTUnwrap(SelectionEngine.select(from: 1, through: 1, page: page()))
        XCTAssertEqual(selected.text, "quiet")
        XCTAssertEqual(selected.sentence, "A quiet garden waits.")
        XCTAssertEqual(selected.wordIDs, [1])
    }

    func testReverseSwipeAcrossLinesKeepsReadingOrderAndPunctuation() throws {
        let selected = try XCTUnwrap(SelectionEngine.select(from: 5, through: 2, page: page()))
        XCTAssertEqual(selected.text, "garden waits. A new")
        XCTAssertEqual(selected.sentence, "A quiet garden waits. A new chapter begins.")
        XCTAssertEqual(selected.wordIDs, [2, 3, 4, 5])
    }

    func testInvalidAndEmptySelectionsReturnNil() {
        XCTAssertNil(SelectionEngine.select(from: -1, through: 1, page: page()))
        XCTAssertNil(SelectionEngine.select(from: 0, through: 100, page: page()))
        XCTAssertNil(SelectionEngine.select(from: 0, through: 0, page: .empty))
    }

    func testUTF16OffsetsPreserveUnicodeAndApostrophes() throws {
        let text = "📚 Anna’s curiosity grew."
        let range = (text as NSString).range(of: "Anna’s")
        let page = OCRPage(text: text, words: [OCRWord(id: 0, text: "Anna’s", bounds: .zero, range: range, lineIndex: 0)],
                           sentenceRanges: [NSRange(location: 0, length: (text as NSString).length)])
        let selection = try XCTUnwrap(SelectionEngine.select(from: 0, through: 0, page: page))
        XCTAssertEqual(selection.text, "Anna’s")
        XCTAssertEqual(selection.sentence, text)
    }

    func testAspectFitFlipsVisionOriginAndAccountsForLetterboxing() {
        let geometry = ImageGeometry(imageSize: CGSize(width: 1000, height: 2000), viewport: CGSize(width: 400, height: 400), scaling: .fit)
        XCTAssertEqual(geometry.imageRect, CGRect(x: 100, y: 0, width: 200, height: 400))
        let rect = geometry.viewRect(for: CGRect(x: 0.1, y: 0.75, width: 0.2, height: 0.1))
        XCTAssertEqual(rect.minX, 120, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 60, accuracy: 0.001)
        XCTAssertEqual(rect.width, 40, accuracy: 0.001)
    }

    func testAspectFillAccountsForCroppedSides() {
        let geometry = ImageGeometry(imageSize: CGSize(width: 2000, height: 1000), viewport: CGSize(width: 300, height: 600), scaling: .fill)
        XCTAssertEqual(geometry.imageRect, CGRect(x: -450, y: 0, width: 1200, height: 600))
        XCTAssertEqual(geometry.viewRect(for: CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)).midX, 210, accuracy: 0.001)
    }

    func testHitTestingRejectsMarginsAndFindsWordInImage() {
        let geometry = ImageGeometry(imageSize: CGSize(width: 1000, height: 2000), viewport: CGSize(width: 400, height: 400), scaling: .fit)
        let word = page().words[0]
        let rect = geometry.viewRect(for: word.bounds)
        XCTAssertEqual(geometry.hitTest(CGPoint(x: rect.midX, y: rect.midY), words: [word]), word.id)
        XCTAssertNil(geometry.hitTest(CGPoint(x: 50, y: 70), words: [word]))
        XCTAssertNil(geometry.hitTest(CGPoint(x: 399, y: 399), words: [word]))
    }

    func testEmptyImageGeometryDoesNotDivideByZero() {
        XCTAssertEqual(ImageGeometry(imageSize: .zero, viewport: CGSize(width: 390, height: 800), scaling: .fit).imageRect, .zero)
    }
}
