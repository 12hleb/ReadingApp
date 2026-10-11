import XCTest
import Translation
@testable import SwipeTranslate

final class TranslationTests: XCTestCase {
    @MainActor func testEachNewSelectionTriggersAnotherTranslationTask() async throws {
        let service = TranslationService()
        service.request("garden")
        var previous = try XCTUnwrap(service.configuration)

        for text in ["curiosity", "chapter", "quiet"] {
            // A tap can clear the old selection and request the new one before
            // SwiftUI renders. Only the final configuration reaches translationTask.
            service.reset()
            XCTAssertEqual(service.state, .idle)
            XCTAssertEqual(service.sourceText, "")
            XCTAssertNil(service.translatedText)
            service.request(text)

            let next = try XCTUnwrap(service.configuration)
            XCTAssertNotEqual(next, previous, "SwiftUI must observe a new task trigger")
            XCTAssertEqual(service.sourceText, text)
            XCTAssertEqual(service.state, .loading)
            previous = next
        }
    }

    @MainActor func testReselectingUnfinishedTextAfterResetRestartsTranslation() async throws {
        let service = TranslationService()
        service.request("garden")
        let first = try XCTUnwrap(service.configuration)

        service.reset()
        service.request("garden")

        XCTAssertNotEqual(try XCTUnwrap(service.configuration), first)
        XCTAssertEqual(service.state, .loading)
    }

    @MainActor func testRepeatedPendingRequestIsCoalescedButExplicitRetryRestarts() async throws {
        let service = TranslationService()
        service.request("garden")
        let first = try XCTUnwrap(service.configuration)

        service.request(" garden ")
        XCTAssertEqual(service.configuration, first)

        service.request("garden", force: true)
        XCTAssertNotEqual(try XCTUnwrap(service.configuration), first)
        XCTAssertEqual(service.state, .loading)
    }
}
