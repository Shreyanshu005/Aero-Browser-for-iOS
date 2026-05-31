import Foundation

struct BrowserSettings: Codable, Equatable {
    var searchEngine: SearchEngine
    var contentBlockerEnabled: Bool
    var newTabBackgroundImagePath: String?
    var agentProviderConfiguration: AgentProviderConfiguration

    static let defaults = BrowserSettings(
        searchEngine: .google,
        contentBlockerEnabled: true,
        newTabBackgroundImagePath: nil,
        agentProviderConfiguration: .defaults
    )

    init(
        searchEngine: SearchEngine = .google,
        contentBlockerEnabled: Bool = true,
        newTabBackgroundImagePath: String? = nil,
        agentProviderConfiguration: AgentProviderConfiguration = .defaults
    ) {
        self.searchEngine = searchEngine
        self.contentBlockerEnabled = contentBlockerEnabled
        self.newTabBackgroundImagePath = newTabBackgroundImagePath
        self.agentProviderConfiguration = agentProviderConfiguration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.searchEngine = (try? container.decode(SearchEngine.self, forKey: .searchEngine)) ?? Self.defaults.searchEngine
        self.contentBlockerEnabled = (try? container.decode(Bool.self, forKey: .contentBlockerEnabled)) ?? Self.defaults.contentBlockerEnabled
        self.newTabBackgroundImagePath = (try? container.decodeIfPresent(String.self, forKey: .newTabBackgroundImagePath)) ?? Self.defaults.newTabBackgroundImagePath
        self.agentProviderConfiguration = (try? container.decode(AgentProviderConfiguration.self, forKey: .agentProviderConfiguration)) ?? Self.defaults.agentProviderConfiguration
    }
}

protocol BrowserSettingsStoring: AgentProviderSettingsPersisting {
    func loadSettings() -> BrowserSettings
    func saveSettings(_ settings: BrowserSettings)
}

protocol AgentProviderSettingsPersisting {
    func loadAgentProviderConfiguration() -> AgentProviderConfiguration
    func saveAgentProviderConfiguration(_ configuration: AgentProviderConfiguration)
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
        let existingSettings = loadSettings()
        var settingsToSave = settings
        // Existing callers save search/privacy only, so preserve independent feature settings.
        if settingsToSave.newTabBackgroundImagePath == nil {
            settingsToSave.newTabBackgroundImagePath = existingSettings.newTabBackgroundImagePath
        }
        if settingsToSave.agentProviderConfiguration == .defaults {
            settingsToSave.agentProviderConfiguration = existingSettings.agentProviderConfiguration
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

extension BrowserSettingsStore: AgentProviderSettingsPersisting {
    func loadAgentProviderConfiguration() -> AgentProviderConfiguration {
        loadSettings().agentProviderConfiguration
    }

    func saveAgentProviderConfiguration(_ configuration: AgentProviderConfiguration) {
        var settings = loadSettings()
        settings.agentProviderConfiguration = configuration
        writeSettings(settings)
    }
}
