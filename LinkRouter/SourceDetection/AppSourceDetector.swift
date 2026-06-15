import AppKit

@MainActor
final class AppSourceDetector {
    static let shared = AppSourceDetector(
        recentApplicationTracker: .shared
    )

    private static let recentApplicationMaximumAge: TimeInterval = 5

    private let recentApplicationTracker: RecentApplicationTracker

    init(recentApplicationTracker: RecentApplicationTracker) {
        self.recentApplicationTracker = recentApplicationTracker
    }

    func start() {
        recentApplicationTracker.start()
    }

    func stop() {
        recentApplicationTracker.stop()
    }

    func detect(
        event: NSAppleEventDescriptor,
        at date: Date = Date()
    ) -> SourceDetectionResult {
        if
            let senderPID = senderProcessIdentifier(from: event),
            let runningApplication = NSRunningApplication(
                processIdentifier: senderPID
            ),
            let application = SourceApplication(runningApplication),
            Self.isCredibleSource(application)
        {
            return SourceDetectionResult(
                application: application,
                method: .appleEventSender,
                confidence: .high,
                reason: "Resolved the sender PID attached to the URL Apple Event."
            )
        }

        if
            let runningApplication = NSWorkspace.shared.frontmostApplication,
            let application = SourceApplication(runningApplication),
            Self.isCredibleSource(application)
        {
            return SourceDetectionResult(
                application: application,
                method: .frontmostApplication,
                confidence: .medium,
                reason: "The Apple Event sender was unavailable or not credible, so the current frontmost app was used."
            )
        }

        if let application = recentApplicationTracker.recentApplication(
            at: date,
            maximumAge: Self.recentApplicationMaximumAge
        ) {
            return SourceDetectionResult(
                application: application,
                method: .recentApplication,
                confidence: .medium,
                reason: "The Apple Event sender was unavailable or not credible, so the most recently active app was used."
            )
        }

        return .unknown(
            reason: "No credible Apple Event sender, frontmost app, or recently active app was available."
        )
    }

    nonisolated static func isCredibleSource(
        _ application: SourceApplication
    ) -> Bool {
        let excludedBundleIdentifiers: Set<String> = [
            "com.apple.CoreServicesUIAgent",
            "com.apple.loginwindow",
            "com.apple.systemuiserver",
            "com.james.LinkRouter"
        ]

        return !excludedBundleIdentifiers.contains(
            application.bundleIdentifier
        )
    }

    private func senderProcessIdentifier(
        from event: NSAppleEventDescriptor
    ) -> pid_t? {
        guard let descriptor = event.attributeDescriptor(
            forKeyword: keySenderPIDAttr
        ) else {
            return nil
        }

        let processIdentifier = descriptor.int32Value
        guard processIdentifier > 0 else {
            return nil
        }

        return pid_t(processIdentifier)
    }
}
