import Foundation

enum FinderHostAction: String, Equatable, CaseIterable {
    case createCustomFile = "create-custom-file"
    case copyToCustomDestination = "copy-to-custom-destination"
    case moveToCustomDestination = "move-to-custom-destination"
    case repairFilename = "repair-filename"
    case confirmPermanentDelete = "confirm-permanent-delete"
    case archive
}

struct FinderActionRequest: Equatable {
    private static let scheme = "viberight"
    private static let host = "finder-action"

    var action: FinderHostAction
    var selectedURLs: [URL]
    var targetedURL: URL?
    var argument: String?

    init(
        action: FinderHostAction,
        selectedURLs: [URL],
        targetedURL: URL?,
        argument: String? = nil
    ) {
        self.action = action
        self.selectedURLs = selectedURLs.map(\.standardizedFileURL)
        self.targetedURL = targetedURL?.standardizedFileURL
        self.argument = argument
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              url.host?.lowercased() == Self.host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let actionValue = items.first(where: { $0.name == "action" })?.value,
              let action = FinderHostAction(rawValue: actionValue) else {
            return nil
        }

        let selectedURLs = items
            .filter { $0.name == "selected" }
            .compactMap(\.value)
            .filter { $0.hasPrefix("/") }
            .map { URL(fileURLWithPath: $0).standardizedFileURL }
        let targetedURL = items
            .first(where: { $0.name == "target" })?
            .value
            .flatMap { $0.hasPrefix("/") ? URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL : nil }
        guard targetedURL != nil || !selectedURLs.isEmpty else { return nil }

        self.init(
            action: action,
            selectedURLs: selectedURLs,
            targetedURL: targetedURL,
            argument: items.first(where: { $0.name == "argument" })?.value
        )
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [URLQueryItem(name: "action", value: action.rawValue)]
        if let targetedURL {
            components.queryItems?.append(URLQueryItem(name: "target", value: targetedURL.path))
        }
        if let argument {
            components.queryItems?.append(URLQueryItem(name: "argument", value: argument))
        }
        components.queryItems?.append(contentsOf: selectedURLs.map {
            URLQueryItem(name: "selected", value: $0.path)
        })
        return components.url
    }
}
