import Foundation
import Testing
@testable import Aero

struct AeroAgentApprovalPolicyServiceTests {
    @Test func lowRiskObservationIsAllowed() {
        let service = AeroAgentApprovalPolicyService()
        let action = AeroAgentActionDescriptor(
            kind: .observePage,
            summary: "Read visible page text"
        )

        #expect(service.evaluate(action: action) == .allowed)
    }

    @Test func everyRequiredRiskCategoryRequiresApproval() {
        let service = AeroAgentApprovalPolicyService()
        let cases: [(AeroAgentActionKind, AeroAgentRiskCategory)] = [
            (.login, .login),
            (.postContent, .posting),
            (.purchase, .purchase),
            (.payment, .payment),
            (.deleteContent, .deletion),
            (.upload, .upload),
            (.download, .download),
            (.externalAppOpen, .externalAppOpen),
            (.usePrivateData, .privateDataUse),
        ]

        for (kind, risk) in cases {
            let action = AeroAgentActionDescriptor(kind: kind, summary: "Test \(kind.rawValue)")

            guard case .requiresApproval(let prompt) = service.evaluate(action: action) else {
                Issue.record("Expected approval for \(kind.rawValue)")
                continue
            }

            #expect(prompt.riskCategories.contains(risk))
        }
    }

    @Test func privateDataInputsRequireApproval() {
        let service = AeroAgentApprovalPolicyService()
        let action = AeroAgentActionDescriptor(
            kind: .typeText,
            summary: "Fill a form",
            privateDataInputs: ["email"]
        )

        guard case .requiresApproval(let prompt) = service.evaluate(action: action) else {
            Issue.record("Expected private data approval")
            return
        }

        #expect(prompt.riskCategories == [.privateDataUse])
    }

    @Test func externalSchemeNavigationRequiresApproval() {
        let service = AeroAgentApprovalPolicyService()
        let action = AeroAgentActionDescriptor(
            kind: .openURL,
            summary: "Open another app",
            url: URL(string: "mailto:test@example.com")
        )

        guard case .requiresApproval(let prompt) = service.evaluate(action: action) else {
            Issue.record("Expected external app approval")
            return
        }

        #expect(prompt.riskCategories == [.externalAppOpen])
    }

    @Test func mixedRisksAreSortedInPrompt() {
        let service = AeroAgentApprovalPolicyService()
        let action = AeroAgentActionDescriptor(
            kind: .payment,
            summary: "Pay for an order",
            declaredRiskCategories: [.privateDataUse, .purchase]
        )

        guard case .requiresApproval(let prompt) = service.evaluate(action: action) else {
            Issue.record("Expected mixed risk approval")
            return
        }

        #expect(prompt.riskCategories == [.payment, .privateDataUse, .purchase])
    }
}
