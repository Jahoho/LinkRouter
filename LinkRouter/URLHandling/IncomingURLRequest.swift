import Foundation

struct IncomingURLRequest: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let receivedAt: Date
    let source: SourceDetectionResult

    init(
        urlString: String,
        id: UUID = UUID(),
        receivedAt: Date = Date(),
        source: SourceDetectionResult = .unknown(
            reason: "Source detection was not performed."
        )
    ) throws {
        guard
            let components = URLComponents(string: urlString),
            let scheme = components.scheme?.lowercased()
        else {
            throw IncomingURLRequestError.malformedURL
        }

        guard scheme == "http" || scheme == "https" else {
            throw IncomingURLRequestError.unsupportedScheme
        }

        guard
            let host = components.host,
            !host.isEmpty,
            let url = components.url
        else {
            throw IncomingURLRequestError.malformedURL
        }

        self.id = id
        self.url = url
        self.receivedAt = receivedAt
        self.source = source
    }

    var sanitizedDescription: String {
        var components = URLComponents()
        components.scheme = url.scheme?.lowercased()
        components.host = url.host
        components.port = url.port
        return components.string ?? "Unknown web URL"
    }
}

enum IncomingURLRequestError: LocalizedError, Equatable {
    case malformedURL
    case unsupportedScheme

    var errorDescription: String? {
        switch self {
        case .malformedURL:
            return "The incoming value is not a valid web URL."
        case .unsupportedScheme:
            return "LinkRouter currently accepts only HTTP and HTTPS URLs."
        }
    }
}
