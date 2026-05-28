import Foundation

struct AgentResolvedProviderDescriptor: Equatable {
    var providerID: AgentProviderID
    var model: String
    var modelString: String
    var apiKey: String?
    var baseURL: String?
    var accountID: String?
}

enum AgentProviderResolverError: Error, Equatable, LocalizedError {
    case missingAPIKey(AgentProviderID)
    case missingAccountID(AgentProviderID)
    case missingModel(AgentProviderID)
    case invalidBaseURL(String)
    case appleFoundationUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let providerID):
            return "Add an API key for \(providerID.displayName)."
        case .missingAccountID(let providerID):
            return "Add an account ID for \(providerID.displayName)."
        case .missingModel(let providerID):
            return "Add a model for \(providerID.displayName)."
        case .invalidBaseURL(let baseURL):
            return "\(baseURL) is not a valid base URL."
        case .appleFoundationUnavailable(let reason):
            return reason
        }
    }
}

struct AgentProviderResolver {
    var apiKeyStore: AgentAPIKeyStoring

    init(apiKeyStore: AgentAPIKeyStoring = KeychainAgentAPIKeyStore()) {
        self.apiKeyStore = apiKeyStore
    }

    func descriptor(for configuration: AgentProviderConfiguration) throws -> AgentResolvedProviderDescriptor {
        let providerID = configuration.selectedProviderID
        let settings = configuration.settings(for: providerID)
        let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines)

        if providerID == .appleFoundation {
            try validateAppleFoundationAvailability()
        } else if model.isEmpty {
            throw AgentProviderResolverError.missingModel(providerID)
        }

        let apiKey: String?
        if providerID.requiresAPIKey {
            guard let storedKey = try apiKeyStore.apiKey(for: providerID)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !storedKey.isEmpty else {
                throw AgentProviderResolverError.missingAPIKey(providerID)
            }
            apiKey = storedKey
        } else {
            apiKey = nil
        }

        let accountID = settings.accountID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerID.requiresAccountID, accountID?.isEmpty != false {
            throw AgentProviderResolverError.missingAccountID(providerID)
        }

        let baseURL = settings.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if providerID.supportsCustomBaseURL {
            guard let baseURL, !baseURL.isEmpty else {
                throw AgentProviderResolverError.invalidBaseURL("")
            }
            guard URL(string: baseURL) != nil else {
                throw AgentProviderResolverError.invalidBaseURL(baseURL)
            }
        }

        return AgentResolvedProviderDescriptor(
            providerID: providerID,
            model: model.isEmpty ? providerID.defaultModel : model,
            modelString: "\(providerID.modelStringPrefix)/\(model.isEmpty ? providerID.defaultModel : model)",
            apiKey: apiKey,
            baseURL: baseURL,
            accountID: accountID
        )
    }

    private func validateAppleFoundationAvailability() throws {
        if #available(iOS 26, macOS 26, *) {
            return
        }
        throw AgentProviderResolverError.appleFoundationUnavailable("Apple Foundation requires iOS 26 or macOS 26.")
    }
}
