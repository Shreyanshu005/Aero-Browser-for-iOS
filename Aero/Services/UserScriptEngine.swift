import Foundation
import Observation

@Observable
final class UserScriptEngine {

    private(set) var scripts: [UserScriptItem] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("aero_user_scripts.json")
        loadFromDisk()
    }

    func addScript(_ script: UserScriptItem) {
        scripts.append(script)
        saveToDisk()
    }

    func updateScript(_ script: UserScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index] = script
        saveToDisk()
    }

    func removeScript(_ script: UserScriptItem) {
        scripts.removeAll { $0.id == script.id }
        saveToDisk()
    }

    func toggleScript(_ script: UserScriptItem) {
        guard let index = scripts.firstIndex(where: { $0.id == script.id }) else { return }
        scripts[index].isEnabled.toggle()
        saveToDisk()
    }

    func enabledScripts(for url: URL) -> [UserScriptItem] {
        scripts.filter { $0.isEnabled && matchesAnyPattern($0.matchPatterns, url: url) }
    }

    private func matchesAnyPattern(_ patterns: [String], url: URL) -> Bool {
        let urlString = url.absoluteString
        return patterns.contains { pattern in
            if pattern == "*://*/*" { return true }
            let escaped = pattern
                .replacingOccurrences(of: ".", with: "\\.")
                .replacingOccurrences(of: "*", with: ".*")
            return urlString.range(of: "^\(escaped)$", options: .regularExpression) != nil
        }
    }

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save user scripts: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            scripts = try JSONDecoder().decode([UserScriptItem].self, from: data)
        } catch {
            print("[Aero] Failed to load user scripts: \(error)")
        }
    }
}
