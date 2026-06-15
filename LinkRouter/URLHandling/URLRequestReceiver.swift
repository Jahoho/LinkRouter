import AppKit

final class URLRequestReceiver {
    static let shared = URLRequestReceiver()

    private var isListening = false

    private init() {}

    func start() {
        guard !isListening else {
            return
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        isListening = true
        RoutingLogger.shared.logListenerStarted()
    }

    func stop() {
        guard isListening else {
            return
        }

        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        isListening = false
    }

    @objc
    private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            RoutingLogger.shared.logRejected(.malformedURL)
            return
        }

        do {
            let request = try IncomingURLRequest(urlString: urlString)

            Task { @MainActor in
                AppState.shared.record(request)
            }
        } catch let error as IncomingURLRequestError {
            RoutingLogger.shared.logRejected(error)
        } catch {
            RoutingLogger.shared.logUnexpectedError(error)
        }
    }
}
