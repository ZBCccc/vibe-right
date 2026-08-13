import Foundation

struct FinderContextSnapshot: Equatable {
    static let fieldSeparator = "\u{1F}"
    static let itemSeparator = "\u{1E}"

    var selectedURLs: [URL]
    var targetedURL: URL?

    init(selectedURLs: [URL], targetedURL: URL?) {
        self.selectedURLs = selectedURLs.map(\.standardizedFileURL)
        self.targetedURL = targetedURL?.standardizedFileURL
    }

    init?(serialized: String) {
        let fields = serialized.components(separatedBy: Self.fieldSeparator)
        guard fields.count == 2 else { return nil }

        let selected = fields[1]
            .components(separatedBy: Self.itemSeparator)
            .filter { !$0.isEmpty && $0.hasPrefix("/") }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
        let target = fields[0].hasPrefix("/")
            ? URL(fileURLWithPath: fields[0], isDirectory: true).standardizedFileURL
            : nil
        let fallbackTarget = selected.first?.deletingLastPathComponent()
        guard target != nil || fallbackTarget != nil else { return nil }

        self.init(selectedURLs: selected, targetedURL: target ?? fallbackTarget)
    }

    var requiresAlternateMenu: Bool {
        let urls = [targetedURL].compactMap { $0 } + selectedURLs
        return urls.contains(where: Self.isCloudProviderURL)
    }

    static func isCloudProviderURL(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = ConfigStore.userHomeDirectory.standardizedFileURL.path
        let cloudRoots = [
            home + "/Library/Mobile Documents",
            home + "/Library/CloudStorage"
        ]
        if cloudRoots.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return true }

        let homeRelative = path.hasPrefix(home + "/")
            ? String(path.dropFirst(home.count + 1))
            : ""
        if homeRelative == "OneDrive" || homeRelative.hasPrefix("OneDrive-") || homeRelative.hasPrefix("OneDrive/") {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]).isUbiquitousItem) == true
    }
}
