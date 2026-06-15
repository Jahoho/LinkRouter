import Foundation

enum ConfigurationLoadStatus: Equatable {
    case loaded
    case createdSeed
    case usingInMemoryFallback(String)

    var title: String {
        switch self {
        case .loaded:
            return "Loaded from disk"
        case .createdSeed:
            return "Created default configuration"
        case .usingInMemoryFallback:
            return "Using in-memory fallback"
        }
    }

    var detail: String {
        switch self {
        case .loaded:
            return "The saved configuration passed validation."
        case .createdSeed:
            return "A new schema version \(RoutingConfiguration.currentSchemaVersion) configuration was created."
        case let .usingInMemoryFallback(reason):
            return reason
        }
    }

    var isUsingInMemoryFallback: Bool {
        if case .usingInMemoryFallback = self {
            return true
        }

        return false
    }
}

struct ConfigurationLoadResult: Equatable {
    let configuration: RoutingConfiguration
    let status: ConfigurationLoadStatus
}

enum ConfigurationStoreError: LocalizedError, Equatable {
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            return "Configuration schema version \(version) is not supported."
        }
    }
}

final class ConfigurationStore {
    static let shared = ConfigurationStore()

    private static let directoryName = "LinkRouter"
    private static let fileName = "routing-config.json"

    private let fileManager: FileManager
    let directoryURL: URL
    let configurationURL: URL

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager

        let resolvedDirectoryURL = directoryURL
            ?? Self.defaultDirectoryURL(fileManager: fileManager)

        self.directoryURL = resolvedDirectoryURL
        self.configurationURL = resolvedDirectoryURL.appendingPathComponent(
            Self.fileName,
            isDirectory: false
        )
    }

    func loadOrCreateSeed() -> ConfigurationLoadResult {
        guard fileManager.fileExists(atPath: configurationURL.path) else {
            do {
                try save(.seed)
                return ConfigurationLoadResult(
                    configuration: .seed,
                    status: .createdSeed
                )
            } catch {
                return fallbackResult(
                    reason:
                        "The default configuration could not be saved: \(error.localizedDescription)"
                )
            }
        }

        do {
            let data = try Data(contentsOf: configurationURL)
            let configuration = try JSONDecoder().decode(
                RoutingConfiguration.self,
                from: data
            )
            try validate(configuration)

            return ConfigurationLoadResult(
                configuration: configuration,
                status: .loaded
            )
        } catch {
            // Keep the original file available for manual recovery.
            return fallbackResult(
                reason:
                    "The saved configuration was preserved but could not be loaded: \(error.localizedDescription)"
            )
        }
    }

    func save(_ configuration: RoutingConfiguration) throws {
        try validate(configuration)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: configurationURL, options: .atomic)
    }

    private func validate(
        _ configuration: RoutingConfiguration
    ) throws {
        guard
            configuration.schemaVersion
                == RoutingConfiguration.currentSchemaVersion
        else {
            throw ConfigurationStoreError.unsupportedSchemaVersion(
                configuration.schemaVersion
            )
        }
    }

    private func fallbackResult(reason: String) -> ConfigurationLoadResult {
        ConfigurationLoadResult(
            configuration: .seed,
            status: .usingInMemoryFallback(reason)
        )
    }

    private static func defaultDirectoryURL(
        fileManager: FileManager
    ) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support",
                isDirectory: true
            )

        return applicationSupportURL.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }
}
