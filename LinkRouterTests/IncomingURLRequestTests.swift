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
}
