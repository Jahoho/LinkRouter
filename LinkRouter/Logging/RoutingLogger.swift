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
        logger.notice(
            "Received URL: \(request.sanitizedDescription, privacy: .public)"
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
