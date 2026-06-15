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
