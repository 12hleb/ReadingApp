import XCTest
import UIKit
@testable import SwipeTranslate

final class OCRTests: XCTestCase {
    func testOrderingGroupsSlightlySkewedFragmentsBeforeNextLine() {
        func line(_ text: String, x: CGFloat, y: CGFloat) -> RecognizedLine {
            RecognizedLine(text: text, bounds: CGRect(x: x, y: y, width: 0.2, height: 0.04), tokens: [])
        }
        let lines = [line("third", x: 0.1, y: 0.6), line("second", x: 0.5, y: 0.81), line("first", x: 0.1, y: 0.8)]
        XCTAssertEqual(OCRResultProcessor.readingOrder(lines).map(\.text), ["first", "second", "third"])
    }

    func testFixtureProducesSelectableWordsAndNormalizedBoxes() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "sample-page", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        let page = try OCRService.recognize(image)
        XCTAssertTrue(page.text.lowercased().contains("curiosity"), page.text)
        XCTAssertTrue(page.text.lowercased().contains("garden"), page.text)
        XCTAssertGreaterThan(page.words.count, 30)
        for word in page.words {
            XCTAssertGreaterThan(word.bounds.width, 0)
            XCTAssertGreaterThan(word.bounds.height, 0)
            XCTAssertGreaterThanOrEqual(word.bounds.minX, -0.01)
            XCTAssertGreaterThanOrEqual(word.bounds.minY, -0.01)
            XCTAssertLessThanOrEqual(word.bounds.maxX, 1.01)
            XCTAssertLessThanOrEqual(word.bounds.maxY, 1.01)
            XCTAssertEqual((page.text as NSString).substring(with: word.range), word.text)
        }
        let curiosity = try XCTUnwrap(page.words.first { $0.text.lowercased() == "curiosity" })
        let selection = try XCTUnwrap(SelectionEngine.select(from: curiosity.id, through: curiosity.id, page: page))
        XCTAssertEqual(selection.text.lowercased(), "curiosity")
        XCTAssertTrue(selection.sentence?.lowercased().contains("unfamiliar") == true)
    }

    func testCoverTitleSuggestionUsesProminentText() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "sample-page", withExtension: "png"))
        let image = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        XCTAssertTrue(try OCRService.suggestTitle(in: image).lowercased().contains("garden"))
    }

    func testEmptyOCRResultProducesEmptyPage() {
        let page = OCRResultProcessor.assemble([]) { _ in [] }
        XCTAssertTrue(page.words.isEmpty)
        XCTAssertTrue(page.text.isEmpty)
        XCTAssertTrue(page.sentenceRanges.isEmpty)
    }
}
