import AppKit
import Foundation

enum TextServiceError: LocalizedError {
    case emptyText
    case invalidURL
    case openFailed(URL)
    case pasteboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .emptyText: return "没有收到可处理的文本"
        case .invalidURL: return "无法构造服务地址"
        case .openFailed(let url): return "无法打开：\(url.absoluteString)"
        case .pasteboardWriteFailed: return "无法写入二维码到剪贴板"
        }
    }
}

enum TranslationProvider: String, CaseIterable {
    case baidu
    case google
}

enum TextServices {
    static func translationURL(
        for text: String,
        provider: TranslationProvider,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) throws -> URL {
        let sourceText = try normalizedText(text)
        let targetLanguage = translationTargetLanguage(preferredLanguages: preferredLanguages)
        switch provider {
        case .baidu:
            let target = targetLanguage.hasPrefix("zh") ? "zh" : targetLanguage
            return try fragmentURL(
                base: "https://fanyi.baidu.com/mtpe-individual/transText",
                path: "/auto/\(target)/\(sourceText)"
            )
        case .google:
            var components = URLComponents(string: "https://translate.google.com/")
            components?.queryItems = [
                URLQueryItem(name: "sl", value: "auto"),
                URLQueryItem(name: "tl", value: targetLanguage),
                URLQueryItem(name: "text", value: sourceText),
                URLQueryItem(name: "op", value: "translate")
            ]
            guard let url = components?.url else { throw TextServiceError.invalidURL }
            return url
        }
    }

    static func translationTargetLanguage(preferredLanguages: [String]) -> String {
        let preferred = preferredLanguages.first?.replacingOccurrences(of: "_", with: "-").lowercased() ?? ""
        if preferred.hasPrefix("zh-hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") {
            return "zh-TW"
        }
        if preferred.hasPrefix("zh") { return "zh-CN" }
        if preferred.hasPrefix("ja") { return "ja" }
        if preferred.hasPrefix("ko") { return "ko" }
        if preferred.hasPrefix("fr") { return "fr" }
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("pt") { return "pt" }
        if preferred.hasPrefix("de") { return "de" }
        return "en"
    }

    static func readText(from pasteboard: NSPasteboard) throws -> String {
        if let value = pasteboard.string(forType: .string) {
            return try normalizedText(value)
        }
        let legacyType = NSPasteboard.PasteboardType("NSStringPboardType")
        if let value = pasteboard.string(forType: legacyType) {
            return try normalizedText(value)
        }
        throw TextServiceError.emptyText
    }

    static func writeQRCode(for text: String, to pasteboard: NSPasteboard) throws {
        let sourceText = try normalizedText(text)
        let data = try FileOperations.qrCodePNGData(from: sourceText)
        let image = NSImage(data: data)
        pasteboard.clearContents()
        pasteboard.declareTypes([.png, .tiff], owner: nil)
        guard pasteboard.setData(data, forType: .png) else {
            throw TextServiceError.pasteboardWriteFailed
        }
        if let tiff = image?.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
    }

    private static func normalizedText(_ text: String) throws -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TextServiceError.emptyText }
        return normalized
    }

    private static func fragmentURL(base: String, path: String) throws -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?%")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              var components = URLComponents(string: base) else {
            throw TextServiceError.invalidURL
        }
        components.percentEncodedFragment = encoded
        guard let url = components.url else { throw TextServiceError.invalidURL }
        return url
    }
}

@objc final class TextServiceProvider: NSObject {
    @objc func translateWithBaidu(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        openTranslation(.baidu, pasteboard: pasteboard, error: errorPointer)
    }

    @objc func translateWithGoogle(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        openTranslation(.google, pasteboard: pasteboard, error: errorPointer)
    }

    @objc func generateQRCode(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        do {
            let text = try TextServices.readText(from: pasteboard)
            try TextServices.writeQRCode(for: text, to: pasteboard)
        } catch {
            errorPointer.pointee = error.localizedDescription as NSString
        }
    }

    private func openTranslation(
        _ provider: TranslationProvider,
        pasteboard: NSPasteboard,
        error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        do {
            let text = try TextServices.readText(from: pasteboard)
            let url = try TextServices.translationURL(for: text, provider: provider)
            guard NSWorkspace.shared.open(url) else { throw TextServiceError.openFailed(url) }
        } catch {
            errorPointer.pointee = error.localizedDescription as NSString
        }
    }
}
