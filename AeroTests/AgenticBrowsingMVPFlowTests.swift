import Foundation
import Testing
@testable import Aero

struct AgenticBrowsingMVPFlowTests {
    @Test func shoppingResolutionCanOpenThroughBrowserActionWithoutApproval() {
        let resolution = AgentSiteResolver().resolve(
            "find iPhone price on Flipkart",
            searchEngine: .google
        )
        let request = BrowserActionRequest(
            kind: .openURL,
            url: resolution.url.absoluteString
        )
        let approval = AeroAgentApprovalPolicyService().evaluate(
            action: AeroAgentActionDescriptor(
                kind: .openURL,
                summary: "Open \(resolution.url.host ?? "site")",
                url: resolution.url
            )
        )

        #expect(resolution.kind == .flipkartSearch)
        #expect(resolution.query == "iPhone")
        #expect(request.url == "https://www.flipkart.com/search?q=iPhone")
        #expect(approval == .allowed)
    }

    @Test func observedElementTargetIDsCanFeedBrowserActions() {
        let targetPath = "html:nth-of-type(1)>body:nth-of-type(1)>form:nth-of-type(1)>input:nth-of-type(1)"
        let targetID = PageElementTargetConvention.makeTargetID(
            kind: .input,
            targetPath: targetPath
        )

        let typeRequest = BrowserActionRequest(
            kind: .typeText,
            elementID: BrowserElementID(rawValue: targetID),
            text: "iphone"
        )
        let enterRequest = BrowserActionRequest(
            kind: .pressEnter,
            elementID: BrowserElementID(rawValue: targetID)
        )

        #expect(typeRequest.elementID?.rawValue == targetID)
        #expect(enterRequest.elementID == typeRequest.elementID)
        #expect(targetID.hasPrefix(PageElementTargetConvention.targetIDPrefix))
    }

    @Test func observedLinksCanBeAdaptedIntoExtractionInput() {
        let targetPath = "html:nth-of-type(1)>body:nth-of-type(1)>a:nth-of-type(1)"
        let observedLink = PageObservedLink(
            targetID: PageElementTargetConvention.makeTargetID(kind: .link, targetPath: targetPath),
            targetPath: targetPath,
            text: "iPhone 16",
            url: "/iphone-16",
            title: nil,
            ariaLabel: nil
        )
        let input = AgentExtractionInput(
            url: URL(string: "https://store.example/search")!,
            visibleText: "iPhone 16 from $799",
            elements: [
                AgentExtractionElement(
                    id: observedLink.targetID,
                    tagName: "a",
                    text: observedLink.text,
                    attributes: ["href": observedLink.url ?? ""]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.links, .prices], from: input)

        #expect(bundle.links.first?.text == "iPhone 16")
        #expect(bundle.links.first?.url.absoluteString == "https://store.example/iphone-16")
        #expect(bundle.prices.first?.text == "$799")
    }

    @Test func sensitiveExternalNavigationRequiresApprovalBeforeAction() {
        let action = AeroAgentActionDescriptor(
            kind: .openURL,
            summary: "Open mail composer",
            url: URL(string: "mailto:support@example.com")
        )

        guard case .requiresApproval(let prompt) = AeroAgentApprovalPolicyService().evaluate(action: action) else {
            Issue.record("Expected external app approval")
            return
        }

        #expect(prompt.riskCategories == [.externalAppOpen])
        #expect(prompt.host == nil)
    }
}
