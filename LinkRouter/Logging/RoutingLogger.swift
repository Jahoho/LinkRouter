import OSLog

final class RoutingLogger {
    static let shared = RoutingLogger()

    private let logger = Logger(
        subsystem: "com.james.LinkRouter",
        category: "URLHandling"
    )

    private init() {}

    func logListenerStarted() {
        logger.notice("URL listener started")
    }

    func logReceived(_ request: IncomingURLRequest) {
        let sourceName = request.source.application?.name ?? "Unknown"
        let bundleIdentifier = request.source.application?.bundleIdentifier ?? "Unknown"

        logger.notice(
            """
            Received URL: \(request.sanitizedDescription, privacy: .public); \
            source: \(sourceName, privacy: .public); \
            bundle: \(bundleIdentifier, privacy: .public); \
            method: \(request.source.method.rawValue, privacy: .public); \
            confidence: \(request.source.confidence.rawValue, privacy: .public); \
            reason: \(request.source.reason, privacy: .public)
            """
        )
    }

    func logRejected(_ error: IncomingURLRequestError) {
        logger.error(
            "Rejected incoming URL: \(error.localizedDescription, privacy: .public)"
        )
    }

    func logUnexpectedError(_ error: Error) {
        logger.fault(
            "Unexpected URL handling error: \(error.localizedDescription, privacy: .private)"
        )
    }
}
