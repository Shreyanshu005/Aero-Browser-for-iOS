import Foundation
import Security

protocol AgentAPIKeyStoring {
    func apiKey(for providerID: AgentProviderID) throws -> String?
    func saveAPIKey(_ apiKey: String, for providerID: AgentProviderID) throws
    func deleteAPIKey(for providerID: AgentProviderID) throws
}

enum AgentAPIKeyStoreError: Error, LocalizedError {
    case invalidStoredData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidStoredData:
            return "The saved API key could not be read."
        case .unexpectedStatus(let status):
            return "Keychain returned status \(status)."
        }
    }
}

final class KeychainAgentAPIKeyStore: AgentAPIKeyStoring {
    private let service: String

    init(service: String = KeychainAgentAPIKeyStore.defaultService) {
        self.service = service
    }

    func apiKey(for providerID: AgentProviderID) throws -> String? {
        var query = baseQuery(for: providerID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                throw AgentAPIKeyStoreError.invalidStoredData
            }
            return apiKey
        case errSecItemNotFound:
            return nil
        default:
            throw AgentAPIKeyStoreError.unexpectedStatus(status)
        }
    }

    func saveAPIKey(_ apiKey: String, for providerID: AgentProviderID) throws {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            try deleteAPIKey(for: providerID)
            return
        }

        let data = Data(trimmedAPIKey.utf8)
        let query = baseQuery(for: providerID)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AgentAPIKeyStoreError.unexpectedStatus(addStatus)
            }
        default:
            throw AgentAPIKeyStoreError.unexpectedStatus(status)
        }
    }

    func deleteAPIKey(for providerID: AgentProviderID) throws {
        let status = SecItemDelete(baseQuery(for: providerID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AgentAPIKeyStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for providerID: AgentProviderID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID.keychainAccount,
        ]
    }

    private static var defaultService: String {
        if let bundleID = Bundle.main.bundleIdentifier {
            return "\(bundleID).agent-api-keys"
        }

        return "aero.agent-api-keys"
    }
}
