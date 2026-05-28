import Foundation

@MainActor
final class LiveAgentBrowserTools: AgentBrowserTooling {
    var onApprovalRequested: ((AgentApprovalRequest) -> Void)?
    var onApprovalResolved: ((AgentApprovalRequest, AgentApprovalDecision) -> Void)?

    private weak var target: BrowserActionTarget?
    private let actionExecutor: BrowserActionExecutor
    private let extractionService: AgentExtractionService
    private var approvalContinuations: [UUID: CheckedContinuation<AgentApprovalDecision, Never>] = [:]
    private var queuedApprovalDecisions: [UUID: AgentApprovalDecision] = [:]

    init(
        target: BrowserActionTarget,
        actionExecutor: BrowserActionExecutor = BrowserActionExecutor(),
        extractionService: AgentExtractionService = AgentExtractionService()
    ) {
        self.target = target
        self.actionExecutor = actionExecutor
        self.extractionService = extractionService
    }

    func observePage() async throws -> AgentPageObservation {
        let observation = try await observeRawPage()
        return AgentPageObservation(
            title: observation.title,
            url: observation.url.flatMap(URL.init(string:)),
            visibleText: observation.visibleTextSummary,
            elements: observation.elements.map { element in
                AgentPageElement(
                    id: element.targetID,
                    role: element.kind.rawValue,
                    label: element.label,
                    text: element.text ?? ""
                )
            }
        )
    }

    func openURL(_ url: URL) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(kind: .openURL, url: url.absoluteString)
        )
    }

    func click(elementID: String) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(kind: .clickElement, elementID: BrowserElementID(rawValue: elementID)),
            approvalTitle: "Allow click",
            approvalDetail: "The agent wants to click a page element that may submit or share data."
        )
    }

    func type(_ text: String, into elementID: String?) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(
                kind: .typeText,
                elementID: elementID.map(BrowserElementID.init(rawValue:)),
                text: text
            )
        )
    }

    func pressKey(_ key: AgentBrowserKey) async throws -> AgentBrowserToolResult {
        guard key == .enter else {
            throw LiveAgentBrowserToolsError.unsupportedKey(key)
        }

        return try await execute(
            BrowserActionRequest(kind: .pressEnter),
            approvalTitle: "Allow Enter",
            approvalDetail: "The agent wants to press Enter on the page, which may submit a form."
        )
    }

    func scroll(_ direction: AgentScrollDirection) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(
                kind: .scroll,
                scroll: BrowserScrollRequest(direction: BrowserScrollDirection(direction))
            )
        )
    }

    func wait(seconds: TimeInterval) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(
                kind: .wait,
                waitMilliseconds: Int(max(0, seconds) * 1_000)
            )
        )
    }

    func extractData(_ request: AgentDataExtractionRequest) async throws -> AgentBrowserToolResult {
        let observation = try await observeRawPage()
        let bundle = extractionService.extract(
            from: AgentExtractionInput(
                url: observation.url.flatMap(URL.init(string:)),
                title: observation.title,
                visibleText: observation.visibleTextSummary,
                elements: extractionElements(from: observation)
            )
        )

        return AgentBrowserToolResult(summary: summary(for: bundle))
    }

    func requestApproval(_ request: AgentApprovalRequest) async -> AgentApprovalDecision {
        if let decision = queuedApprovalDecisions.removeValue(forKey: request.id) {
            return decision
        }

        return await withCheckedContinuation { continuation in
            approvalContinuations[request.id] = continuation
        }
    }

    @discardableResult
    func resolveApproval(id: UUID, decision: AgentApprovalDecision) -> Bool {
        if let continuation = approvalContinuations.removeValue(forKey: id) {
            continuation.resume(returning: decision)
            return true
        }

        queuedApprovalDecisions[id] = decision
        return false
    }

    func cancelPendingApprovals() {
        let continuations = approvalContinuations
        approvalContinuations.removeAll()
        queuedApprovalDecisions.removeAll()

        for continuation in continuations.values {
            continuation.resume(returning: .denied)
        }
    }

    private func execute(
        _ request: BrowserActionRequest,
        approvalTitle: String? = nil,
        approvalDetail: String? = nil
    ) async throws -> AgentBrowserToolResult {
        guard let target else {
            throw LiveAgentBrowserToolsError.missingBrowserTarget
        }

        var activeRequest = request
        var result = await actionExecutor.execute(activeRequest, in: target)

        if result.status == .approvalRequired {
            let approval = AgentApprovalRequest(
                kind: .browserAction,
                title: approvalTitle ?? "Allow browser action",
                detail: approvalDetail ?? result.message
            )
            onApprovalRequested?(approval)
            let decision = await requestApproval(approval)
            onApprovalResolved?(approval, decision)

            guard decision == .approved else {
                throw LiveAgentBrowserToolsError.approvalDenied
            }

            activeRequest.userApproved = true
            result = await actionExecutor.execute(activeRequest, in: target)
        }

        guard result.status == .succeeded else {
            throw LiveAgentBrowserToolsError.actionFailed(result.message)
        }

        return AgentBrowserToolResult(summary: result.message)
    }

    private func observeRawPage() async throws -> PageObservation {
        guard let target else {
            throw LiveAgentBrowserToolsError.missingBrowserTarget
        }

        guard let json = try await target.browserActionEvaluateJavaScript(PageObservationService.observationJavaScript) as? String else {
            throw PageObservationServiceError.invalidJavaScriptResult
        }

        return try PageObservationService.decodeObservation(from: json)
    }

    private func extractionElements(from observation: PageObservation) -> [AgentExtractionElement] {
        var elements: [AgentExtractionElement] = []

        elements.append(
            contentsOf: observation.links.map { link in
                AgentExtractionElement(
                    id: link.targetID,
                    tagName: "a",
                    text: link.text,
                    attributes: compactAttributes([
                        "href": link.url,
                        "title": link.title,
                        "aria-label": link.ariaLabel,
                        "data-aero-target-path": link.targetPath,
                    ])
                )
            }
        )

        elements.append(
            contentsOf: observation.buttons.map { button in
                AgentExtractionElement(
                    id: button.targetID,
                    tagName: "button",
                    text: button.text,
                    attributes: compactAttributes([
                        "type": button.type,
                        "name": button.name,
                        "aria-label": button.ariaLabel,
                        "disabled": button.isDisabled ? "true" : nil,
                        "data-aero-target-path": button.targetPath,
                    ])
                )
            }
        )

        elements.append(
            contentsOf: observation.inputs.map { input in
                AgentExtractionElement(
                    id: input.targetID,
                    tagName: "input",
                    text: input.label,
                    attributes: compactAttributes([
                        "type": input.type,
                        "name": input.name,
                        "placeholder": input.placeholder,
                        "value": input.value,
                        "aria-label": input.label,
                        "required": input.isRequired ? "true" : nil,
                        "disabled": input.isDisabled ? "true" : nil,
                        "data-aero-target-path": input.targetPath,
                    ])
                )
            }
        )

        elements.append(
            contentsOf: observation.forms.map { form in
                AgentExtractionElement(
                    id: form.targetID,
                    tagName: "form",
                    text: form.label,
                    attributes: compactAttributes([
                        "action": form.action,
                        "method": form.method,
                        "data-aero-target-path": form.targetPath,
                    ])
                )
            }
        )

        let knownIDs = Set(elements.compactMap(\.id))
        elements.append(
            contentsOf: observation.elements.compactMap { element in
                guard !knownIDs.contains(element.targetID) else { return nil }

                return AgentExtractionElement(
                    id: element.targetID,
                    tagName: element.kind.rawValue,
                    text: element.text ?? element.label,
                    attributes: compactAttributes([
                        "aria-label": element.label,
                        "disabled": element.isEnabled ? nil : "true",
                        "data-aero-target-path": element.targetPath,
                    ])
                )
            }
        )

        return elements
    }

    private func compactAttributes(_ attributes: [String: String?]) -> [String: String] {
        attributes.compactMapValues { value in
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
                return nil
            }

            return value
        }
    }

    private func summary(for bundle: AgentExtractionBundle) -> String {
        var sections: [String] = []

        appendSection("Links", items: bundle.links.prefix(6).map { "\($0.text) - \($0.url.absoluteString)" }, to: &sections)
        appendSection("Headings", items: bundle.headings.prefix(6).map { "H\($0.level): \($0.text)" }, to: &sections)
        appendSection("Prices", items: bundle.prices.prefix(6).map(\.text), to: &sections)
        appendSection("Products", items: bundle.productCards.prefix(4).map { product in
            [product.title, product.price?.text].compactMap { $0 }.joined(separator: " - ")
        }, to: &sections)
        appendSection("Posts", items: bundle.posts.prefix(4).map { post in
            [post.author, post.body].compactMap { $0 }.joined(separator: ": ")
        }, to: &sections)
        appendSection("Search results", items: bundle.searchResults.prefix(5).map { "\($0.title) - \($0.url.absoluteString)" }, to: &sections)

        return sections.isEmpty ? "No structured data found on the visible page." : sections.joined(separator: "\n\n")
    }

    private func appendSection<T: Collection>(
        _ title: String,
        items: T,
        to sections: inout [String]
    ) where T.Element == String {
        let values = items.map { compact($0, limit: 220) }.filter { !$0.isEmpty }
        guard !values.isEmpty else { return }

        sections.append("\(title):\n" + values.map { "- \($0)" }.joined(separator: "\n"))
    }

    private func compact(_ text: String, limit: Int) -> String {
        let cleaned = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > limit else { return cleaned }
        return String(cleaned.prefix(limit)) + "..."
    }
}

private extension BrowserScrollDirection {
    init(_ direction: AgentScrollDirection) {
        switch direction {
        case .up:
            self = .up
        case .down:
            self = .down
        case .left:
            self = .left
        case .right:
            self = .right
        }
    }
}

private enum LiveAgentBrowserToolsError: LocalizedError {
    case missingBrowserTarget
    case unsupportedKey(AgentBrowserKey)
    case approvalDenied
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingBrowserTarget:
            return "No browser target is available for the agent."
        case .unsupportedKey(let key):
            return "The agent cannot press \(key.rawValue) yet."
        case .approvalDenied:
            return "Approval was denied."
        case .actionFailed(let message):
            return message
        }
    }
}
