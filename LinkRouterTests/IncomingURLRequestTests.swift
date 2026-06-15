import XCTest
@testable import LinkRouter

final class IncomingURLRequestTests: XCTestCase {
    func testAcceptsHTTPAndHTTPSURLs() throws {
        let httpRequest = try IncomingURLRequest(urlString: "http://example.com")
        let httpsRequest = try IncomingURLRequest(urlString: "https://example.com")

        XCTAssertEqual(httpRequest.url.scheme, "http")
        XCTAssertEqual(httpsRequest.url.scheme, "https")
    }

    func testSanitizedDescriptionRemovesSensitiveURLParts() throws {
        let request = try IncomingURLRequest(
            urlString: "https://user:password@example.com:8443/private?token=secret#section"
        )

        XCTAssertEqual(request.sanitizedDescription, "https://example.com:8443")
    }

    func testRejectsUnsupportedScheme() {
        XCTAssertThrowsError(
            try IncomingURLRequest(urlString: "file:///Users/example/private.txt")
        ) { error in
            XCTAssertEqual(error as? IncomingURLRequestError, .unsupportedScheme)
        }
    }

    func testRejectsWebURLWithoutHost() {
        XCTAssertThrowsError(
            try IncomingURLRequest(urlString: "https:///missing-host")
        ) { error in
            XCTAssertEqual(error as? IncomingURLRequestError, .malformedURL)
        }
    }

    func testStoresSourceDetectionResult() throws {
        let source = SourceDetectionResult(
            application: SourceApplication(
                bundleIdentifier: "com.openai.codex",
                name: "Codex",
                processIdentifier: 123
            ),
            method: .appleEventSender,
            confidence: .high,
            reason: "Test sender"
        )

        let request = try IncomingURLRequest(
            urlString: "https://example.com",
            source: source
        )

        XCTAssertEqual(request.source, source)
    }

    func testRejectsLinkRouterAsCredibleSource() {
        let application = SourceApplication(
            bundleIdentifier: "com.james.LinkRouter",
            name: "LinkRouter",
            processIdentifier: 123
        )

        XCTAssertFalse(AppSourceDetector.isCredibleSource(application))
    }

    func testAcceptsCodexAsCredibleSource() {
        let application = SourceApplication(
            bundleIdentifier: "com.openai.codex",
            name: "Codex",
            processIdentifier: 123
        )

        XCTAssertTrue(AppSourceDetector.isCredibleSource(application))
    }

}
