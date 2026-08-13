import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.text("跟随系统")
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .french: return "Français"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .german: return "Deutsch"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system: return AppLanguage.resolved(.system).localeIdentifier
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .english: return "en"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .french: return "fr"
        case .spanish: return "es"
        case .portuguese: return "pt"
        case .german: return "de"
        }
    }

    static func resolved(
        _ language: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> AppLanguage {
        guard language == .system else { return language }
        let preferred = preferredLanguages.first?
            .replacingOccurrences(of: "_", with: "-")
            .lowercased() ?? ""
        if preferred.hasPrefix("zh-hant")
            || preferred.hasPrefix("zh-tw")
            || preferred.hasPrefix("zh-hk")
            || preferred.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        if preferred.hasPrefix("ja") { return .japanese }
        if preferred.hasPrefix("ko") { return .korean }
        if preferred.hasPrefix("fr") { return .french }
        if preferred.hasPrefix("es") { return .spanish }
        if preferred.hasPrefix("pt") { return .portuguese }
        if preferred.hasPrefix("de") { return .german }
        return .english
    }
}

enum L10n {
    static let resourceBundleName = "Localization"
    static let tableName = "Localizable"
    static let fallbackLanguage = AppLanguage.simplifiedChinese

    private(set) static var language: AppLanguage = .system
    private static var resourceBundle: Bundle? = discoverResourceBundle(in: .main)
    private static var localizedBundles: [AppLanguage: Bundle] = [:]

    static var resolvedLanguage: AppLanguage {
        AppLanguage.resolved(language)
    }

    static func configure(language: AppLanguage, resourceBundle: Bundle? = nil) {
        self.language = language
        if let resourceBundle {
            self.resourceBundle = resourceBundle
            localizedBundles.removeAll()
        } else if self.resourceBundle == nil {
            self.resourceBundle = discoverResourceBundle(in: .main)
        }
    }

    static func discoverResourceBundle(in hostBundle: Bundle) -> Bundle? {
        guard let url = hostBundle.url(forResource: resourceBundleName, withExtension: "bundle") else {
            return nil
        }
        return Bundle(url: url)
    }

    static func text(_ key: String) -> String {
        text(key, language: language)
    }

    static func text(
        _ key: String,
        language selectedLanguage: AppLanguage,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let resolved = AppLanguage.resolved(selectedLanguage, preferredLanguages: preferredLanguages)
        if let value = localizedValue(for: key, language: resolved) { return value }
        if resolved != fallbackLanguage,
           let fallback = localizedValue(for: key, language: fallbackLanguage) {
            return fallback
        }
        return key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: Locale(identifier: resolvedLanguage.localeIdentifier),
            arguments: arguments
        )
    }

    static func availableTranslations(
        for language: AppLanguage,
        resourceBundle: Bundle? = nil
    ) -> [String: String] {
        let bundle = resourceBundle ?? self.resourceBundle
        guard language != .system,
              let path = bundle?.path(forResource: language.rawValue, ofType: "lproj"),
              let strings = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Localizable.strings"))
                as? [String: String] else {
            return [:]
        }
        return strings
    }

    private static func localizedValue(for key: String, language: AppLanguage) -> String? {
        guard let bundle = localizedBundle(for: language) else { return nil }
        let missingMarker = "__VIBE_RIGHT_MISSING_LOCALIZATION__"
        let value = bundle.localizedString(forKey: key, value: missingMarker, table: tableName)
        return value == missingMarker ? nil : value
    }

    private static func localizedBundle(for language: AppLanguage) -> Bundle? {
        guard language != .system else { return nil }
        if let cached = localizedBundles[language] { return cached }
        guard let path = resourceBundle?.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        localizedBundles[language] = bundle
        return bundle
    }
}
