import Foundation

enum FinderScope {
    static func contextURLs(selected: [URL], targeted: URL?) -> [URL] {
        selected.isEmpty ? [targeted].compactMap { $0 } : selected
    }

    static func isExternalVolume(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path == "/Volumes" || path.hasPrefix("/Volumes/")
    }
}
