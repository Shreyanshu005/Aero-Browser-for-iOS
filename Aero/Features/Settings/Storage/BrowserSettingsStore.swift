import Foundation

struct BrowserSettings: Codable, Equatable {
    var searchEngine: SearchEngine
    var contentBlockerEnabled: Bool

    static let defaults = BrowserSettings(searchEngine: .google, contentBlockerEnabled: true)

    init(searchEngine: SearchEngine = .google, contentBlockerEnabled: Bool = true) {
        self.searchEngine = searchEngine
        self.contentBlockerEnabled = contentBlockerEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.searchEngine = (try? container.decode(SearchEngine.self, forKey: .searchEngine)) ?? Self.defaults.searchEngine
        self.contentBlockerEnabled = (try? container.decode(Bool.self, forKey: .contentBlockerEnabled)) ?? Self.defaults.contentBlockerEnabled
    }
}

protocol BrowserSettingsStoring {
    func loadSettings() -> BrowserSettings
    func saveSettings(_ settings: BrowserSettings)
}

final class BrowserSettingsStore: BrowserSettingsStoring {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("aero_settings.json")
        }
    }

    func loadSettings() -> BrowserSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(BrowserSettings.self, from: data)
        } catch {
            print("[Aero] Failed to load settings: \(error)")
            return .defaults
        }
    }

    func saveSettings(_ settings: BrowserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save settings: \(error)")
        }
    }
}
