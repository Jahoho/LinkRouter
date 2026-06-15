import AppKit

@MainActor
final class BrowserLauncher {
    static let shared = BrowserLauncher()

    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func open(
        _ url: URL,
        in browser: Browser,
        activate: Bool = true,
        completion: @escaping (Result<NSRunningApplication, BrowserLaunchError>) -> Void
    ) {
        guard
            let scheme = url.scheme?.lowercased(),
            (scheme == "http" || scheme == "https"),
            url.host != nil
        else {
            completion(.failure(.invalidWebURL))
            return
        }

        guard BrowserDiscovery.isAllowedDestination(
            bundleIdentifier: browser.bundleIdentifier
        ) else {
            completion(.failure(.routingLoopPrevented))
            return
        }

        guard let applicationURL = workspace.urlForApplication(
            withBundleIdentifier: browser.bundleIdentifier
        ) else {
            completion(.failure(.browserNotInstalled(browser.name)))
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        configuration.addsToRecentItems = false
        configuration.allowsRunningApplicationSubstitution = false
        configuration.promptsUserIfNeeded = true

        workspace.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { runningApplication, error in
            Task { @MainActor in
                if let error {
                    completion(
                        .failure(
                            .workspaceFailure(error.localizedDescription)
                        )
                    )
                } else if let runningApplication {
                    completion(.success(runningApplication))
                } else {
                    completion(.failure(.missingLaunchResult))
                }
            }
        }
    }
}

enum BrowserLaunchError: LocalizedError, Equatable {
    case invalidWebURL
    case routingLoopPrevented
    case browserNotInstalled(String)
    case workspaceFailure(String)
    case missingLaunchResult

    var errorDescription: String? {
        switch self {
        case .invalidWebURL:
            return "Only valid HTTP and HTTPS URLs can be opened."
        case .routingLoopPrevented:
            return "LinkRouter cannot open a link in itself."
        case let .browserNotInstalled(browserName):
            return "\(browserName) is not installed or cannot be located."
        case let .workspaceFailure(message):
            return "macOS could not open the browser: \(message)"
        case .missingLaunchResult:
            return "macOS did not return a browser process after opening the link."
        }
    }
}
