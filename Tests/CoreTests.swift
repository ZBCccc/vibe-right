import Foundation

@main
struct CoreTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeRightTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let template = FileTemplate(id: "json", name: "JSON", fileExtension: "json", enabled: true, isDirectory: false)
        let first = try FileOperations.create(template: template, in: root)
        let second = try FileOperations.create(template: template, in: root)
        precondition(first.lastPathComponent == "未命名.json")
        precondition(second.lastPathComponent == "未命名 2.json")
        let firstContents = try Data(contentsOf: first)
        precondition(String(data: firstContents, encoding: .utf8) == "{}\n")

        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileOperations.copy([first], to: destination)
        try FileOperations.copy([first], to: destination)
        precondition(FileManager.default.fileExists(atPath: destination.appendingPathComponent("未命名.json").path))
        precondition(FileManager.default.fileExists(atPath: destination.appendingPathComponent("未命名 2.json").path))

        let configURL = root.appendingPathComponent("config.json")
        let store = ConfigStore(configURL: configURL)
        try store.update { $0.playSound = false }
        let reloaded = ConfigStore(configURL: configURL)
        precondition(reloaded.config.playSound == false)

        let digest = try FileOperations.checksum(of: first, algorithm: "sha256")
        precondition(digest.count == 64)
        print("CoreTests passed")
    }
}
