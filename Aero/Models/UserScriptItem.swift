import Foundation
import WebKit

struct UserScriptItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var source: String
    var matchPatterns: [String]
    var injectionTime: InjectionTime
    var isEnabled: Bool

    enum InjectionTime: String, Codable, Hashable {
        case atDocumentStart
        case atDocumentEnd

        var wkInjectionTime: WKUserScriptInjectionTime {
            switch self {
            case .atDocumentStart: return .atDocumentStart
            case .atDocumentEnd: return .atDocumentEnd
            }
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        source: String,
        matchPatterns: [String] = ["*://*/*"],
        injectionTime: InjectionTime = .atDocumentEnd,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.matchPatterns = matchPatterns
        self.injectionTime = injectionTime
        self.isEnabled = isEnabled
    }
}
