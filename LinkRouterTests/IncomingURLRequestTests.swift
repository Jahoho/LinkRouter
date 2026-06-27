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

    func testInfersOutermostAppFromNestedHelperExecutablePath() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "LinkRouterSourceApplicationTests-\(UUID().uuidString)",
                isDirectory: true
            )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let outerAppURL = temporaryDirectory
            .appendingPathComponent("Codex.app", isDirectory: true)
        let helperExecutableURL = outerAppURL
            .appendingPathComponent(
                "Contents/Frameworks/Helper.app/Contents/MacOS/helper",
                isDirectory: false
            )

        try FileManager.default.createDirectory(
            at: outerAppURL.appendingPathComponent(
                "Contents",
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: helperExecutableURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: helperExecutableURL)

        let infoPlist: [String: String] = [
            "CFBundleIdentifier": "com.openai.codex",
            "CFBundleDisplayName": "Codex"
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: infoPlist,
            format: .xml,
            options: 0
        )
        try plistData.write(
            to: outerAppURL.appendingPathComponent(
                "Contents/Info.plist",
                isDirectory: false
            )
        )

        let inferredInfo = try XCTUnwrap(
            SourceApplication.inferredApplicationInfo(
                executableURL: helperExecutableURL
            )
        )

        XCTAssertEqual(inferredInfo.bundleIdentifier, "com.openai.codex")
        XCTAssertEqual(inferredInfo.name, "Codex")
    }

}
