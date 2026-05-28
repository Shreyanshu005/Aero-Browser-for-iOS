import Foundation

struct AeroAgentApprovalPrompt: Codable, Equatable, Sendable {
    var title: String
    var message: String
    var actionSummary: String
    var host: String?
    var payloadPreview: String?
    var riskCategories: [AeroAgentRiskCategory]
}
enum AeroAgentApprovalOutcome: Equatable, Sendable {
    case allowed
    case requiresApproval(AeroAgentApprovalPrompt)
    case blocked(reason: String)
}

struct AeroAgentApprovalPolicyService {
    func evaluate(
        action: AeroAgentActionDescriptor,
        context: AeroAgentApprovalContext = AeroAgentApprovalContext()
    ) -> AeroAgentApprovalOutcome {
        let risks = riskCategories(for: action, context: context)

        guard !risks.isEmpty else {
            return .allowed
        }

        return .requiresApproval(
            AeroAgentApprovalPrompt(
                title: approvalTitle(for: risks),
                message: approvalMessage(for: risks, action: action),
                actionSummary: action.summary,
                host: action.host ?? context.pageURL?.host,
                payloadPreview: action.payloadPreview,
                riskCategories: risks.sorted { $0.rawValue < $1.rawValue }
            )
        )
    }

    func riskCategories(
        for action: AeroAgentActionDescriptor,
        context: AeroAgentApprovalContext = AeroAgentApprovalContext()
    ) -> Set<AeroAgentRiskCategory> {
        var risks = action.declaredRiskCategories

        switch action.kind {
        case .login:
            risks.insert(.login)
        case .postContent, .submitForm:
            risks.insert(.posting)
        case .purchase:
            risks.insert(.purchase)
        case .payment:
            risks.insert(.payment)
        case .deleteContent:
            risks.insert(.deletion)
        case .upload:
            risks.insert(.upload)
        case .download:
            risks.insert(.download)
        case .externalAppOpen:
            risks.insert(.externalAppOpen)
        case .usePrivateData:
            risks.insert(.privateDataUse)
        case .observePage, .openURL, .clickElement, .typeText, .clearField, .pressEnter, .scroll, .wait, .goBack, .goForward, .reload, .stop, .extractData:
            break
        }

        if !action.privateDataInputs.isEmpty {
            risks.insert(.privateDataUse)
        }

        if context.isPrivateBrowsing, action.kind == .extractData {
            risks.insert(.privateDataUse)
        }

        if action.kind == .openURL,
           let scheme = action.url?.scheme?.lowercased(),
           !["http", "https"].contains(scheme) {
            risks.insert(.externalAppOpen)
        }

        return risks
    }

    private func approvalTitle(for risks: Set<AeroAgentRiskCategory>) -> String {
        if risks.contains(.payment) || risks.contains(.purchase) {
            return "Approve Purchase"
        }
        if risks.contains(.login) {
            return "Approve Login"
        }
        if risks.contains(.posting) {
            return "Approve Posting"
        }
        if risks.contains(.privateDataUse) {
            return "Approve Private Data Use"
        }
        return "Approve Agent Action"
    }

    private func approvalMessage(
        for risks: Set<AeroAgentRiskCategory>,
        action: AeroAgentActionDescriptor
    ) -> String {
        let riskNames = risks
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: ", ")

        return "The agent wants to continue with an action involving \(riskNames): \(action.summary)"
    }
}

private extension AeroAgentRiskCategory {
    var displayName: String {
        switch self {
        case .login:
            return "login"
        case .posting:
            return "posting"
        case .purchase:
            return "purchase"
        case .payment:
            return "payment"
        case .deletion:
            return "deletion"
        case .upload:
            return "upload"
        case .download:
            return "download"
        case .externalAppOpen:
            return "external app"
        case .privateDataUse:
            return "private data"
        }
    }
}
