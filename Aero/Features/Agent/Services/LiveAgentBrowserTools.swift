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
        actionExecutor: BrowserActionExecutor? = nil,
        extractionService: AgentExtractionService = AgentExtractionService()
    ) {
        self.target = target
        self.actionExecutor = actionExecutor ?? BrowserActionExecutor()
        self.extractionService = extractionService
    }

    func observePage() async throws -> AgentPageObservation {
        try await observeRawPage().agentPageObservation
    }

    func openURL(_ url: URL) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(kind: .openURL, url: url.absoluteString)
        )
    }

    func click(elementID: String) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(
                kind: .clickElement,
                elementID: BrowserElementID(rawValue: elementID)
            )
        )
    }

    func type(_ text: String, into elementID: String?) async throws -> AgentBrowserToolResult {
        try await execute(
            BrowserActionRequest(
                kind: .typeText,
                elementID: elementID.map { BrowserElementID(rawValue: $0) },
                text: text
            )
        )
    }

    func pressKey(_ key: AgentBrowserKey) async throws -> AgentBrowserToolResult {
        guard key == .enter else {
            throw LiveAgentBrowserToolsError.unsupportedKey(key)
        }

        return try await execute(BrowserActionRequest(kind: .pressEnter))
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
                waitMilliseconds: waitMilliseconds(from: seconds)
            )
        )
    }

    func extractData(_ request: AgentDataExtractionRequest) async throws -> AgentBrowserToolResult {
        let observation = try await observeRawPage()
        let extractionInput = observation.agentExtractionInput
        let bundle = extractionService.extract(request.kinds, from: extractionInput)

        return AgentBrowserToolResult(
            summary: extractionSummary(for: bundle),
            pageObservation: observation.agentPageObservation,
            extractionInput: extractionInput,
            extractionBundle: bundle
        )
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

    private func observeRawPage() async throws -> PageObservation {
        guard let target else {
            throw LiveAgentBrowserToolsError.browserUnavailable
        }

        guard let json = try await target.browserActionEvaluateJavaScript(PageObservationService.observationJavaScript) as? String else {
            throw PageObservationServiceError.invalidJavaScriptResult
        }

        return try PageObservationService.decodeObservation(from: json)
    }

    private func execute(_ request: BrowserActionRequest) async throws -> AgentBrowserToolResult {
        guard let target else {
            throw LiveAgentBrowserToolsError.browserUnavailable
        }

        var activeRequest = request
        var result = await actionExecutor.execute(activeRequest, in: target)

        guard result.status == .approvalRequired else {
            return toolResult(from: result)
        }

        let approval = approvalRequest(for: result)
        onApprovalRequested?(approval)
        let decision = await requestApproval(approval)
        onApprovalResolved?(approval, decision)

        guard decision == .approved else {
            return AgentBrowserToolResult(
                summary: "Approval denied. \(result.message)",
                actionResult: result,
                approvalDecision: decision
            )
        }

        activeRequest.userApproved = true
        result = await actionExecutor.execute(activeRequest, in: target)
        return toolResult(from: result, approvalDecision: decision)
    }

    private func toolResult(
        from result: BrowserActionResult,
        approvalDecision: AgentApprovalDecision? = nil
    ) -> AgentBrowserToolResult {
        AgentBrowserToolResult(
            summary: result.message,
            actionResult: result,
            approvalDecision: approvalDecision
        )
    }

    private func approvalRequest(for result: BrowserActionResult) -> AgentApprovalRequest {
        let label = result.element.flatMap { $0.label }.flatMap { $0.nonEmptyTrimmed } ?? "the selected element"
        let pageHost = result.pageURL.flatMap { $0.host }.flatMap { $0.nonEmptyTrimmed }
        let pageURL = result.pageURL.map { $0.absoluteString }.flatMap { $0.nonEmptyTrimmed }
        let host = pageHost ?? pageURL ?? "the current page"

        return AgentApprovalRequest(
            kind: .sensitiveAction,
            title: "Approve browser action",
            detail: "\(result.message) Target: \(label). Page: \(host)."
        )
    }

    private func waitMilliseconds(from seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let maxSeconds = Double(Int.max / 1_000)
        return Int((min(seconds, maxSeconds) * 1_000).rounded())
    }

    private func extractionSummary(for bundle: AgentExtractionBundle) -> String {
        let counts = [
            ("posts", bundle.posts.count),
            ("prices", bundle.prices.count),
            ("product cards", bundle.productCards.count),
            ("links", bundle.links.count),
            ("headings", bundle.headings.count),
            ("tables", bundle.tables.count),
            ("search results", bundle.searchResults.count),
        ]
            .filter { $0.1 > 0 }
            .map { "\($0.1) \($0.0)" }

        guard !counts.isEmpty else {
            return "No structured data extracted."
        }
        return "Extracted \(counts.joined(separator: ", "))."
    }
}

enum LiveAgentBrowserToolsError: Error, Equatable, LocalizedError {
    case browserUnavailable
    case unsupportedKey(AgentBrowserKey)

    var errorDescription: String? {
        switch self {
        case .browserUnavailable:
            return "No active browser is available."
        case .unsupportedKey(let key):
            return "The live browser tools adapter does not support the \(key.rawValue) key yet."
        }
    }
}

private extension PageObservation {
    var agentPageObservation: AgentPageObservation {
        AgentPageObservation(
            title: title,
            url: url.flatMap(URL.init(string:)),
            visibleText: visibleTextSummary,
            elements: agentPageElements
        )
    }

    var agentExtractionInput: AgentExtractionInput {
        let inputByID = Dictionary(inputs.map { ($0.targetID, $0) }, uniquingKeysWith: { first, _ in first })
        var includedIDs = Set<String>()
        var extractionElements: [AgentExtractionElement] = []

        for form in forms {
            guard includedIDs.insert(form.targetID).inserted else { continue }
            extractionElements.append(form.agentExtractionElement(inputByID: inputByID))
            includedIDs.formUnion(form.fieldTargetIDs)
        }

        for link in links {
            guard includedIDs.insert(link.targetID).inserted else { continue }
            extractionElements.append(link.agentExtractionElement)
        }

        for button in buttons {
            guard includedIDs.insert(button.targetID).inserted else { continue }
            extractionElements.append(button.agentExtractionElement)
        }

        for input in inputs {
            guard includedIDs.insert(input.targetID).inserted else { continue }
            extractionElements.append(input.agentExtractionElement)
        }

        for element in elements {
            guard includedIDs.insert(element.targetID).inserted else { continue }
            extractionElements.append(element.agentExtractionElement)
        }

        return AgentExtractionInput(
            url: url.flatMap(URL.init(string:)),
            title: title,
            visibleText: visibleTextSummary,
            elements: extractionElements
        )
    }

    private var agentPageElements: [AgentPageElement] {
        var includedIDs = Set<String>()
        var pageElements: [AgentPageElement] = []

        for link in links {
            guard includedIDs.insert(link.targetID).inserted else { continue }
            pageElements.append(link.agentPageElement)
        }

        for button in buttons {
            guard includedIDs.insert(button.targetID).inserted else { continue }
            pageElements.append(button.agentPageElement)
        }

        for input in inputs {
            guard includedIDs.insert(input.targetID).inserted else { continue }
            pageElements.append(input.agentPageElement)
        }

        for form in forms {
            guard includedIDs.insert(form.targetID).inserted else { continue }
            pageElements.append(form.agentPageElement)
        }

        for element in elements {
            guard includedIDs.insert(element.targetID).inserted else { continue }
            pageElements.append(element.agentPageElement)
        }

        return pageElements
    }
}

private extension PageObservedLink {
    var agentPageElement: AgentPageElement {
        AgentPageElement(
            id: targetID,
            role: "link",
            label: ariaLabel.flatMap { $0.nonEmptyTrimmed } ?? title.flatMap { $0.nonEmptyTrimmed } ?? text.nonEmptyTrimmed ?? url ?? "Link",
            text: text
        )
    }

    var agentExtractionElement: AgentExtractionElement {
        AgentExtractionElement(
            id: targetID,
            tagName: "a",
            text: text,
            attributes: compactedAttributes([
                BrowserActionJavaScript.elementIDAttribute: targetID,
                "data-aero-target-path": targetPath,
                "href": url,
                "title": title,
                "aria-label": ariaLabel,
            ])
        )
    }
}

private extension PageObservedButton {
    var agentPageElement: AgentPageElement {
        AgentPageElement(
            id: targetID,
            role: "button",
            label: ariaLabel.flatMap { $0.nonEmptyTrimmed } ?? text.nonEmptyTrimmed ?? name.flatMap { $0.nonEmptyTrimmed } ?? "Button",
            text: text
        )
    }

    var agentExtractionElement: AgentExtractionElement {
        AgentExtractionElement(
            id: targetID,
            tagName: "button",
            text: text,
            attributes: compactedAttributes([
                BrowserActionJavaScript.elementIDAttribute: targetID,
                "data-aero-target-path": targetPath,
                "type": type,
                "name": name,
                "aria-label": ariaLabel,
                "disabled": isDisabled ? "true" : nil,
            ])
        )
    }
}

private extension PageObservedInput {
    var agentPageElement: AgentPageElement {
        AgentPageElement(
            id: targetID,
            role: "input",
            label: label.nonEmptyTrimmed ?? placeholder.flatMap { $0.nonEmptyTrimmed } ?? name.flatMap { $0.nonEmptyTrimmed } ?? type,
            text: value ?? ""
        )
    }

    var agentExtractionElement: AgentExtractionElement {
        AgentExtractionElement(
            id: targetID,
            tagName: extractionTagName,
            text: value ?? label,
            attributes: compactedAttributes([
                BrowserActionJavaScript.elementIDAttribute: targetID,
                "data-aero-target-path": targetPath,
                "type": type,
                "name": name,
                "placeholder": placeholder,
                "value": value,
                "aria-label": label,
                "required": isRequired ? "true" : nil,
                "disabled": isDisabled ? "true" : nil,
                "data-aero-search-field": isSearchField ? "true" : nil,
            ])
        )
    }

    private var extractionTagName: String {
        switch type.lowercased() {
        case "textarea", "select":
            return type.lowercased()
        default:
            return "input"
        }
    }
}

private extension PageObservedForm {
    var agentPageElement: AgentPageElement {
        AgentPageElement(
            id: targetID,
            role: "form",
            label: label.nonEmptyTrimmed ?? action.flatMap { $0.nonEmptyTrimmed } ?? "Form",
            text: method
        )
    }

    func agentExtractionElement(inputByID: [String: PageObservedInput]) -> AgentExtractionElement {
        AgentExtractionElement(
            id: targetID,
            tagName: "form",
            text: label,
            attributes: compactedAttributes([
                BrowserActionJavaScript.elementIDAttribute: targetID,
                "data-aero-target-path": targetPath,
                "action": action,
                "method": method,
                "data-aero-field-ids": fieldTargetIDs.joined(separator: " "),
                "data-aero-search-field-ids": searchFieldTargetIDs.joined(separator: " "),
            ]),
            children: fieldTargetIDs.map { fieldID in
                inputByID[fieldID]?.agentExtractionElement
                    ?? AgentExtractionElement(id: fieldID, tagName: "input")
            }
        )
    }
}

private extension PageObservedElement {
    var agentPageElement: AgentPageElement {
        AgentPageElement(
            id: targetID,
            role: role.flatMap { $0.nonEmptyTrimmed } ?? kind.rawValue,
            label: label.nonEmptyTrimmed ?? text.flatMap { $0.nonEmptyTrimmed } ?? kind.rawValue,
            text: text ?? ""
        )
    }

    var agentExtractionElement: AgentExtractionElement {
        AgentExtractionElement(
            id: targetID,
            tagName: tagName.flatMap { $0.nonEmptyTrimmed } ?? kind.extractionTagName,
            text: text ?? label,
            attributes: compactedAttributes([
                BrowserActionJavaScript.elementIDAttribute: targetID,
                "data-aero-target-path": targetPath,
                "role": role ?? kind.rawValue,
                "class": className,
                "data-testid": dataTestID,
                "aria-label": label,
                "disabled": isEnabled ? nil : "true",
            ])
        )
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

private extension PageObservedElementKind {
    var extractionTagName: String {
        switch self {
        case .link:
            return "a"
        case .button:
            return "button"
        case .input:
            return "input"
        case .form:
            return "form"
        case .other:
            return "div"
        }
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func compactedAttributes(_ attributes: [String: String?]) -> [String: String] {
    attributes.reduce(into: [:]) { result, pair in
        if let value = pair.value.flatMap({ $0.nonEmptyTrimmed }) {
            result[pair.key] = value
        }
    }
}
