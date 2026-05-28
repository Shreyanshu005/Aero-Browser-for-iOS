import Foundation

enum AgentProviderID: String, CaseIterable, Codable, Hashable, Identifiable {
    case openAI = "openai"
    case anthropic
    case gemini
    case groq
    case openRouter = "openrouter"
    case mistral
    case cohere
    case cloudflare
    case ollama
    case appleFoundation = "applefoundation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .gemini:
            return "Gemini"
        case .groq:
            return "Groq"
        case .openRouter:
            return "OpenRouter"
        case .mistral:
            return "Mistral"
        case .cohere:
            return "Cohere"
        case .cloudflare:
            return "Cloudflare"
        case .ollama:
            return "Ollama"
        case .appleFoundation:
            return "Apple Foundation"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .anthropic:
            return "claude-3-5-sonnet-latest"
        case .gemini:
            return "gemini-2.0-flash"
        case .groq:
            return "llama-3.3-70b-versatile"
        case .openRouter:
            return "meta-llama/llama-3.3-70b-instruct"
        case .mistral:
            return "mistral-large-latest"
        case .cohere:
            return "command-r-plus"
        case .cloudflare:
            return "@cf/meta/llama-3.1-8b-instruct"
        case .ollama:
            return "llama3.2"
        case .appleFoundation:
            return "apple-on-device"
        }
    }

    var defaultBaseURL: String? {
        switch self {
        case .ollama:
            return "http://localhost:11434/v1"
        default:
            return nil
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .ollama, .appleFoundation:
            return false
        default:
            return true
        }
    }

    var requiresAccountID: Bool {
        self == .cloudflare
    }

    var supportsCustomBaseURL: Bool {
        self == .ollama
    }

    var modelStringPrefix: String {
        rawValue
    }

    var keychainAccount: String {
        "agent-provider-\(rawValue)-api-key"
    }

    var supportsBYOK: Bool {
        requiresAPIKey
    }
}

struct AgentProviderSettings: Codable, Equatable {
    var model: String
    var baseURL: String?
    var accountID: String?

    init(
        model: String,
        baseURL: String? = nil,
        accountID: String? = nil
    ) {
        self.model = model
        self.baseURL = baseURL
        self.accountID = accountID
    }
}

struct AgentProviderConfiguration: Codable, Equatable {
    var selectedProviderID: AgentProviderID
    private var settingsByProviderID: [String: AgentProviderSettings]

    static let defaults = AgentProviderConfiguration()

    init(
        selectedProviderID: AgentProviderID = .openAI,
        settingsByProviderID: [String: AgentProviderSettings] = Self.defaultSettingsByProviderID
    ) {
        self.selectedProviderID = selectedProviderID
        self.settingsByProviderID = settingsByProviderID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.selectedProviderID = (try? container.decode(AgentProviderID.self, forKey: .selectedProviderID)) ?? .openAI
        let decodedSettings = (try? container.decode([String: AgentProviderSettings].self, forKey: .settingsByProviderID)) ?? [:]
        self.settingsByProviderID = Self.defaultSettingsByProviderID.merging(decodedSettings) { _, decoded in decoded }
    }

    func settings(for providerID: AgentProviderID) -> AgentProviderSettings {
        settingsByProviderID[providerID.rawValue] ?? Self.defaultSettings(for: providerID)
    }

    mutating func setSettings(_ settings: AgentProviderSettings, for providerID: AgentProviderID) {
        settingsByProviderID[providerID.rawValue] = settings
    }

    func selectedProviderSettings() -> AgentProviderSettings {
        settings(for: selectedProviderID)
    }

    private static let defaultSettingsByProviderID: [String: AgentProviderSettings] = Dictionary(
        uniqueKeysWithValues: AgentProviderID.allCases.map { providerID in
            (providerID.rawValue, defaultSettings(for: providerID))
        }
    )

    private static func defaultSettings(for providerID: AgentProviderID) -> AgentProviderSettings {
        AgentProviderSettings(
            model: providerID.defaultModel,
            baseURL: providerID.defaultBaseURL,
            accountID: nil
        )
    }
}
