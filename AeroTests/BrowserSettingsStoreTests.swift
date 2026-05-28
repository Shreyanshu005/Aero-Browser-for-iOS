import Foundation
import Testing
@testable import Aero

struct BrowserSettingsStoreTests {
    @Test func settingsStoreReturnsDefaultsWhenFileIsMissing() {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = BrowserSettingsStore(fileURL: fileURL)

        #expect(store.loadSettings() == .defaults)
    }

    @Test func settingsStoreSavesAndLoadsSettings() {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let expected = BrowserSettings(searchEngine: .duckDuckGo, contentBlockerEnabled: false)
        let store = BrowserSettingsStore(fileURL: fileURL)

        store.saveSettings(expected)

        #expect(BrowserSettingsStore(fileURL: fileURL).loadSettings() == expected)
    }

    @Test func settingsStoreReturnsDefaultsForCorruptFile() throws {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data("not-json".utf8).write(to: fileURL)

        let store = BrowserSettingsStore(fileURL: fileURL)

        #expect(store.loadSettings() == .defaults)
    }

    @Test func settingsStoreFallsBackOnlyForInvalidFields() throws {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let data = Data(#"{"searchEngine":"Invalid","contentBlockerEnabled":false}"#.utf8)
        try data.write(to: fileURL)

        let settings = BrowserSettingsStore(fileURL: fileURL).loadSettings()

        #expect(settings.searchEngine == .google)
        #expect(settings.contentBlockerEnabled == false)
    }

    @Test func settingsStoreSavesAndLoadsAgentProviderConfiguration() {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = BrowserSettingsStore(fileURL: fileURL)
        var configuration = AgentProviderConfiguration(selectedProviderID: .ollama)
        configuration.setSettings(
            AgentProviderSettings(model: "llama3.1", baseURL: "http://localhost:11434/v1"),
            for: .ollama
        )

        store.saveAgentProviderConfiguration(configuration)

        #expect(BrowserSettingsStore(fileURL: fileURL).loadAgentProviderConfiguration() == configuration)
    }

    @Test func settingsStorePreservesAgentProviderConfigurationWhenSavingBrowserSettings() {
        let fileURL = temporarySettingsFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let store = BrowserSettingsStore(fileURL: fileURL)
        let configuration = AgentProviderConfiguration(selectedProviderID: .ollama)
        store.saveAgentProviderConfiguration(configuration)

        store.saveSettings(BrowserSettings(searchEngine: .bing, contentBlockerEnabled: false))

        let loadedSettings = BrowserSettingsStore(fileURL: fileURL).loadSettings()
        #expect(loadedSettings.searchEngine == .bing)
        #expect(loadedSettings.contentBlockerEnabled == false)
        #expect(loadedSettings.agentProviderConfiguration == configuration)
    }
}

private func temporarySettingsFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("aero_settings_\(UUID().uuidString).json")
}
