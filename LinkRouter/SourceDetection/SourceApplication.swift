import Foundation

struct SourceApplication: Equatable {
    let bundleIdentifier: String
    let name: String
    let processIdentifier: Int32
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
