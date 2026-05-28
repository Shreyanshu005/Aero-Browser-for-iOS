import Foundation
import Testing
@testable import Aero

struct AgentProviderSettingsTests {
    @Test func agentProviderConfigurationFillsMissingProviderDefaults() throws {
        let data = Data(#"{"selectedProviderID":"ollama","settingsByProviderID":{}}"#.utf8)
        let configuration = try JSONDecoder().decode(AgentProviderConfiguration.self, from: data)

        #expect(configuration.selectedProviderID == .ollama)
        #expect(configuration.settings(for: .ollama).model == AgentProviderID.ollama.defaultModel)
        #expect(configuration.settings(for: .ollama).baseURL == AgentProviderID.ollama.defaultBaseURL)
    }

    @Test func resolverRequiresAPIKeyForBYOKProvider() {
        let resolver = AgentProviderResolver(apiKeyStore: InMemoryAgentAPIKeyStore())

        var caughtError: AgentProviderResolverError?
        do {
            _ = try resolver.descriptor(for: .defaults)
        } catch let error as AgentProviderResolverError {
            caughtError = error
        } catch {}

        #expect(caughtError == .missingAPIKey(.openAI))
    }

    @Test func resolverBuildsDescriptorForConfiguredProvider() throws {
        let keyStore = InMemoryAgentAPIKeyStore()
        try keyStore.saveAPIKey("test-api-key", for: .openAI)

        let descriptor = try AgentProviderResolver(apiKeyStore: keyStore)
            .descriptor(for: .defaults)

        #expect(descriptor.providerID == .openAI)
        #expect(descriptor.model == AgentProviderID.openAI.defaultModel)
        #expect(descriptor.modelString == "openai/\(AgentProviderID.openAI.defaultModel)")
        #expect(descriptor.apiKey == "test-api-key")
    }

    @Test func resolverRequiresCloudflareAccountID() throws {
        let keyStore = InMemoryAgentAPIKeyStore()
        try keyStore.saveAPIKey("cf-test-key", for: .cloudflare)
        let configuration = AgentProviderConfiguration(selectedProviderID: .cloudflare)

        var caughtError: AgentProviderResolverError?
        do {
            _ = try AgentProviderResolver(apiKeyStore: keyStore).descriptor(for: configuration)
        } catch let error as AgentProviderResolverError {
            caughtError = error
        } catch {}

        #expect(caughtError == .missingAccountID(.cloudflare))
    }

    @Test func viewModelSavesAPIKeyThroughKeyStore() throws {
        let settingsStore = InMemoryAgentProviderSettingsStore(configuration: .defaults)
        let keyStore = InMemoryAgentAPIKeyStore()
        let viewModel = AgentProviderSettingsViewModel(
            settingsStore: settingsStore,
            apiKeyStore: keyStore
        )

        viewModel.draftAPIKey = " test-api-key "
        viewModel.saveDraftAPIKey()

        let savedAPIKey = try keyStore.apiKey(for: .openAI)

        #expect(savedAPIKey == "test-api-key")
        #expect(viewModel.draftAPIKey.isEmpty)
        #expect(viewModel.selectedProviderHasSavedAPIKey)
        #expect(settingsStore.configuration == .defaults)
    }
}

private final class InMemoryAgentProviderSettingsStore: AgentProviderSettingsPersisting {
    var configuration: AgentProviderConfiguration

    init(configuration: AgentProviderConfiguration) {
        self.configuration = configuration
    }

    func loadAgentProviderConfiguration() -> AgentProviderConfiguration {
        configuration
    }

    func saveAgentProviderConfiguration(_ configuration: AgentProviderConfiguration) {
        self.configuration = configuration
    }
}

private final class InMemoryAgentAPIKeyStore: AgentAPIKeyStoring {
    private var apiKeys: [AgentProviderID: String] = [:]

    func apiKey(for providerID: AgentProviderID) throws -> String? {
        apiKeys[providerID]
    }

    func saveAPIKey(_ apiKey: String, for providerID: AgentProviderID) throws {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAPIKey.isEmpty {
            apiKeys[providerID] = nil
        } else {
            apiKeys[providerID] = trimmedAPIKey
        }
    }

    func deleteAPIKey(for providerID: AgentProviderID) throws {
        apiKeys[providerID] = nil
    }
}
