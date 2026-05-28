import Foundation

enum AeroAgentActionKind: String, Codable, Equatable, Hashable, Sendable {
    case observePage
    case openURL
    case clickElement
    case typeText
    case clearField
    case pressEnter
    case scroll
    case wait
    case goBack
    case goForward
    case reload
    case stop
    case extractData
    case submitForm
    case login
    case postContent
    case purchase
    case payment
    case deleteContent
    case upload
    case download
    case externalAppOpen
    case usePrivateData
}
enum AeroAgentRiskCategory: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case login
    case posting
    case purchase
    case payment
    case deletion
    case upload
    case download
    case externalAppOpen
    case privateDataUse
}

struct AeroAgentActionDescriptor: Codable, Equatable, Sendable {
    var kind: AeroAgentActionKind
    var summary: String
    var url: URL?
    var payloadPreview: String?
    var declaredRiskCategories: Set<AeroAgentRiskCategory>
    var privateDataInputs: [String]

    init(
        kind: AeroAgentActionKind,
        summary: String,
        url: URL? = nil,
        payloadPreview: String? = nil,
        declaredRiskCategories: Set<AeroAgentRiskCategory> = [],
        privateDataInputs: [String] = []
    ) {
        self.kind = kind
        self.summary = summary
        self.url = url
        self.payloadPreview = payloadPreview
        self.declaredRiskCategories = declaredRiskCategories
        self.privateDataInputs = privateDataInputs
    }

    var host: String? {
        url?.host
    }
}

struct AeroAgentApprovalContext: Codable, Equatable, Sendable {
    var pageURL: URL?
    var isPrivateBrowsing: Bool

    init(
        pageURL: URL? = nil,
        isPrivateBrowsing: Bool = false
    ) {
        self.pageURL = pageURL
        self.isPrivateBrowsing = isPrivateBrowsing
    }
}
