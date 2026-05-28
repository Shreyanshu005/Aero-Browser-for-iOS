import Foundation
import Observation

@Observable
final class AgentProviderSettingsViewModel {
    var configuration: AgentProviderConfiguration
    var draftAPIKey: String = ""
    var savedAPIKeyProviderIDs: Set<AgentProviderID> = []
    var errorMessage: String?

    @ObservationIgnored
    private let settingsStore: AgentProviderSettingsPersisting
    @ObservationIgnored
    private let apiKeyStore: AgentAPIKeyStoring

    init(
        settingsStore: AgentProviderSettingsPersisting = BrowserSettingsStore(),
        apiKeyStore: AgentAPIKeyStoring = KeychainAgentAPIKeyStore()
    ) {
        self.settingsStore = settingsStore
        self.apiKeyStore = apiKeyStore
        self.configuration = settingsStore.loadAgentProviderConfiguration()
        refreshSavedAPIKeyStatus()
    }

    var selectedProviderID: AgentProviderID {
        get { configuration.selectedProviderID }
        set {
            guard configuration.selectedProviderID != newValue else { return }
            configuration.selectedProviderID = newValue
            draftAPIKey = ""
            saveConfiguration()
        }
    }

    var selectedProviderSettings: AgentProviderSettings {
        configuration.settings(for: selectedProviderID)
    }

    var selectedProviderHasSavedAPIKey: Bool {
        savedAPIKeyProviderIDs.contains(selectedProviderID)
    }

    func updateModel(_ model: String) {
        var settings = selectedProviderSettings
        settings.model = model
        updateSelectedProviderSettings(settings)
    }

    func updateBaseURL(_ baseURL: String) {
        var settings = selectedProviderSettings
        settings.baseURL = baseURL
        updateSelectedProviderSettings(settings)
    }

    func updateAccountID(_ accountID: String) {
        var settings = selectedProviderSettings
        settings.accountID = accountID
        updateSelectedProviderSettings(settings)
    }

    func saveDraftAPIKey() {
        do {
            try apiKeyStore.saveAPIKey(draftAPIKey, for: selectedProviderID)
            draftAPIKey = ""
            errorMessage = nil
            refreshSavedAPIKeyStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSavedAPIKey() {
        do {
            try apiKeyStore.deleteAPIKey(for: selectedProviderID)
            draftAPIKey = ""
            errorMessage = nil
            refreshSavedAPIKeyStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSavedAPIKeyStatus() {
        var providerIDs = Set<AgentProviderID>()

        for providerID in AgentProviderID.allCases where providerID.requiresAPIKey {
            if let apiKey = try? apiKeyStore.apiKey(for: providerID),
               !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerIDs.insert(providerID)
            }
        }

        savedAPIKeyProviderIDs = providerIDs
    }

    private func updateSelectedProviderSettings(_ settings: AgentProviderSettings) {
        configuration.setSettings(settings, for: selectedProviderID)
        saveConfiguration()
    }

    private func saveConfiguration() {
        settingsStore.saveAgentProviderConfiguration(configuration)
        errorMessage = nil
    }
}
