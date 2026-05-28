import Foundation

struct BrowserSettings: Codable, Equatable {
    var searchEngine: SearchEngine
    var contentBlockerEnabled: Bool
    var newTabBackgroundImagePath: String?

    static let defaults = BrowserSettings(
        searchEngine: .google,
        contentBlockerEnabled: true,
        newTabBackgroundImagePath: nil
    )

    init(
        searchEngine: SearchEngine = .google,
        contentBlockerEnabled: Bool = true,
        newTabBackgroundImagePath: String? = nil
    ) {
        self.searchEngine = searchEngine
        self.contentBlockerEnabled = contentBlockerEnabled
        self.newTabBackgroundImagePath = newTabBackgroundImagePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.searchEngine = (try? container.decode(SearchEngine.self, forKey: .searchEngine)) ?? Self.defaults.searchEngine
        self.contentBlockerEnabled = (try? container.decode(Bool.self, forKey: .contentBlockerEnabled)) ?? Self.defaults.contentBlockerEnabled
        self.newTabBackgroundImagePath = (try? container.decodeIfPresent(String.self, forKey: .newTabBackgroundImagePath)) ?? Self.defaults.newTabBackgroundImagePath
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
        var settingsToSave = settings
        // Existing callers save search/privacy only, so preserve the independent New Tab image setting.
        if settingsToSave.newTabBackgroundImagePath == nil {
            settingsToSave.newTabBackgroundImagePath = loadSettings().newTabBackgroundImagePath
        }

        writeSettings(settingsToSave)
    }

    func saveNewTabBackgroundImagePath(_ path: String?) {
        var settings = loadSettings()
        settings.newTabBackgroundImagePath = path
        writeSettings(settings)
    }

    private func writeSettings(_ settings: BrowserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save settings: \(error)")
        }
    }
}
