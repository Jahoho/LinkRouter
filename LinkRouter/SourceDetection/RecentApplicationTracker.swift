import AppKit

@MainActor
final class RecentApplicationTracker {
    static let shared = RecentApplicationTracker()

    private(set) var mostRecentApplication: SourceApplication?
    private(set) var mostRecentActivationDate: Date?

    private var activationObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard activationObserver == nil else {
            return
        }

        record(NSWorkspace.shared.frontmostApplication, at: Date())

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let runningApplication = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication
            else {
                return
            }

            Task { @MainActor in
                self?.record(runningApplication, at: Date())
            }
        }
    }

    func stop() {
        guard let activationObserver else {
            return
        }

        NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        self.activationObserver = nil
    }

    func recentApplication(
        at date: Date,
        maximumAge: TimeInterval
    ) -> SourceApplication? {
        guard
            let application = mostRecentApplication,
            let activationDate = mostRecentActivationDate,
            date.timeIntervalSince(activationDate) >= 0,
            date.timeIntervalSince(activationDate) <= maximumAge
        else {
            return nil
        }

        return application
    }

    private func record(
        _ runningApplication: NSRunningApplication?,
        at date: Date
    ) {
        guard
            let runningApplication,
            let application = SourceApplication(runningApplication),
            AppSourceDetector.isCredibleSource(application)
        else {
            return
        }

        mostRecentApplication = application
        mostRecentActivationDate = date
    }
}
