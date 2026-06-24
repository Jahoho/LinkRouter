import Foundation

struct Browser: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String
    let applicationURL: URL

    var id: String {
        bundleIdentifier
    }

    init?(
        applicationURL: URL,
        fileManager: FileManager = .default
    ) {
        guard
            fileManager.fileExists(atPath: applicationURL.path),
            let bundle = Bundle(url: applicationURL),
            let bundleIdentifier = bundle.bundleIdentifier,
            !bundleIdentifier.isEmpty
        else {
            return nil
        }

        let displayName = bundle.object(
            forInfoDictionaryKey: "CFBundleDisplayName"
        ) as? String
        let bundleName = bundle.object(
            forInfoDictionaryKey: "CFBundleName"
        ) as? String

        self.bundleIdentifier = bundleIdentifier
        self.name = displayName
            ?? bundleName
            ?? applicationURL.deletingPathExtension().lastPathComponent
        self.applicationURL = applicationURL
    }
}

struct BrowserProfile: Identifiable, Equatable {
    let browserBundleIdentifier: String
    let browserName: String
    let profileDirectory: String
    let profileName: String

    var id: String {
        "\(browserBundleIdentifier)::\(profileDirectory)"
    }
}

struct BrowserProfileDiscovery {
    private static let supportedProfileRoots = [
        "com.google.Chrome": "Google/Chrome",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.brave.Browser": "BraveSoftware/Brave-Browser"
    ]

    static func discoverProfiles(for browsers: [Browser]) -> [BrowserProfile] {
        browsers.flatMap { browser in
            discoverProfiles(for: browser)
        }
    }

    static func discoverProfiles(for browser: Browser) -> [BrowserProfile] {
        guard
            let relativeRoot =
                supportedProfileRoots[browser.bundleIdentifier]
        else {
            return []
        }

        let localStateURL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support",
                isDirectory: true
            )
            .appendingPathComponent(relativeRoot, isDirectory: true)
            .appendingPathComponent("Local State")

        guard let data = try? Data(contentsOf: localStateURL) else {
            return []
        }

        return profiles(
            fromLocalStateData: data,
            browser: browser
        )
    }

    static func supportsProfiles(
        browserBundleIdentifier: String
    ) -> Bool {
        supportedProfileRoots[browserBundleIdentifier] != nil
    }

    static func isValidProfileDirectory(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }

        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: " -_")
        )

        return value.unicodeScalars.allSatisfy {
            allowedCharacters.contains($0)
        }
    }

    static func profiles(
        fromLocalStateData data: Data,
        browser: Browser
    ) -> [BrowserProfile] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let profile = root["profile"] as? [String: Any],
            let infoCache = profile["info_cache"] as? [String: Any]
        else {
            return []
        }

        return infoCache.compactMap { directory, value in
            guard
                isValidProfileDirectory(directory),
                let profileInfo = value as? [String: Any]
            else {
                return nil
            }

            let profileName = profileInfo["name"] as? String
            let displayName =
                profileName?.trimmingCharacters(in: .whitespacesAndNewlines)

            return BrowserProfile(
                browserBundleIdentifier: browser.bundleIdentifier,
                browserName: browser.name,
                profileDirectory: directory,
                profileName: displayName?.isEmpty == false
                    ? displayName!
                    : directory
            )
        }
        .sorted { first, second in
            if first.profileDirectory == "Default" {
                return true
            }

            if second.profileDirectory == "Default" {
                return false
            }

            return first.profileName.localizedCaseInsensitiveCompare(
                second.profileName
            ) == .orderedAscending
        }
    }
}
