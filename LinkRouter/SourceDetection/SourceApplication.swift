import AppKit
import Foundation

struct SourceApplication: Equatable {
    let bundleIdentifier: String
    let name: String
    let processIdentifier: Int32
}

extension SourceApplication {
    init?(_ runningApplication: NSRunningApplication) {
        if let inferredInfo = Self.inferredApplicationInfo(
            executableURL: runningApplication.executableURL
        ) {
            self.init(
                bundleIdentifier: inferredInfo.bundleIdentifier,
                name: inferredInfo.name,
                processIdentifier: runningApplication.processIdentifier
            )
            return
        }

        guard
            let bundleIdentifier = runningApplication.bundleIdentifier,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        self.init(
            bundleIdentifier: bundleIdentifier,
            name: runningApplication.localizedName ?? bundleIdentifier,
            processIdentifier: runningApplication.processIdentifier
        )
    }

    static func inferredApplicationInfo(
        executableURL: URL?
    ) -> (bundleIdentifier: String, name: String)? {
        guard
            let executableURL,
            let applicationURL = outermostApplicationURL(
                containing: executableURL
            ),
            let bundle = Bundle(url: applicationURL),
            let bundleIdentifier = bundle.bundleIdentifier,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        return (
            bundleIdentifier,
            applicationName(
                from: bundle,
                applicationURL: applicationURL
            )
        )
    }

    private static func outermostApplicationURL(
        containing url: URL
    ) -> URL? {
        let pathComponents = url.standardizedFileURL.pathComponents

        guard
            let applicationIndex = pathComponents.firstIndex(where: {
                $0.hasSuffix(".app")
            })
        else {
            return nil
        }

        let applicationPath = NSString.path(
            withComponents: Array(
                pathComponents.prefix(applicationIndex + 1)
            )
        )

        return URL(fileURLWithPath: applicationPath, isDirectory: true)
    }

    private static func applicationName(
        from bundle: Bundle,
        applicationURL: URL
    ) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? applicationURL
                .deletingPathExtension()
                .lastPathComponent
    }
}

struct RecentSourceApplication: Identifiable, Equatable {
    let application: SourceApplication
    let lastSeenAt: Date
    let method: SourceDetectionMethod
    let confidence: SourceDetectionConfidence

    var id: String {
        application.bundleIdentifier
    }
}

enum SourceDetectionMethod: String, Equatable {
    case appleEventSender = "Apple Event sender"
    case frontmostApplication = "Frontmost app"
    case recentApplication = "Recent active app"
    case unknown = "Unknown"
}

enum SourceDetectionConfidence: String, Equatable {
    case high = "High"
    case medium = "Medium"
    case unknown = "Unknown"
}

struct SourceDetectionResult: Equatable {
    let application: SourceApplication?
    let method: SourceDetectionMethod
    let confidence: SourceDetectionConfidence
    let reason: String

    static func unknown(reason: String) -> SourceDetectionResult {
        SourceDetectionResult(
            application: nil,
            method: .unknown,
            confidence: .unknown,
            reason: reason
        )
    }
}
