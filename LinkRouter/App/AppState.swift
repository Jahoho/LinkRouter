import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published private(set) var lastRequest: IncomingURLRequest?
    @Published private(set) var receivedRequestCount = 0

    private init() {}

    func record(_ request: IncomingURLRequest) {
        lastRequest = request
        receivedRequestCount += 1
        RoutingLogger.shared.logReceived(request)
    }
}
