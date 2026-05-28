import Foundation

@MainActor
extension BrowserViewModel: AgentBrowserTooling {
    func observePage() async throws -> AgentPageObservation {
        let observation = try await PageObservationService().observe(webView: activeTab?.webView)
        return AgentPageObservation(observation)
    }

    func openURL(_ url: URL) async throws -> AgentBrowserToolResult {
        try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(kind: .openURL, url: url.absoluteString),
                in: self
            )
        )
    }

    func click(elementID: String) async throws -> AgentBrowserToolResult {
        try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(
                    kind: .clickElement,
                    elementID: BrowserElementID(rawValue: elementID)
                ),
                in: self
            )
        )
    }

    func type(_ text: String, into elementID: String?) async throws -> AgentBrowserToolResult {
        try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(
                    kind: .typeText,
                    elementID: elementID.map { BrowserElementID(rawValue: $0) },
                    text: text
                ),
                in: self
            )
        )
    }

    func pressKey(_ key: AgentBrowserKey) async throws -> AgentBrowserToolResult {
        let requestKind: BrowserActionKind
        switch key {
        case .enter:
            requestKind = .pressEnter
        case .escape, .tab, .backspace:
            throw AgentBrowserToolingError.unsupportedKey(key.rawValue)
        }

        return try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(kind: requestKind),
                in: self
            )
        )
    }

    func scroll(_ direction: AgentScrollDirection) async throws -> AgentBrowserToolResult {
        try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(
                    kind: .scroll,
                    scroll: BrowserScrollRequest(direction: BrowserScrollDirection(direction))
                ),
                in: self
            )
        )
    }

    func wait(seconds: TimeInterval) async throws -> AgentBrowserToolResult {
        try actionResult(
            await BrowserActionExecutor().execute(
                BrowserActionRequest(
                    kind: .wait,
                    waitMilliseconds: max(0, Int(seconds * 1_000))
                ),
                in: self
            )
        )
    }

    func extractData(_ request: AgentDataExtractionRequest) async throws -> AgentBrowserToolResult {
        let observation = try await PageObservationService().observe(webView: activeTab?.webView)
        let input = AgentExtractionInput(observation)
        let extraction = AgentExtractionService().extract(request.kinds, from: input)
        return AgentBrowserToolResult(
            summary: extraction.summary,
            extraction: extraction
        )
    }

    func requestApproval(_ request: AgentApprovalRequest) async -> AgentApprovalDecision {
        .denied
    }

    private func actionResult(_ result: BrowserActionResult) throws -> AgentBrowserToolResult {
        guard result.status == .succeeded else {
            throw AgentBrowserToolingError.actionFailed(result.message)
        }

        return AgentBrowserToolResult(summary: result.message)
    }
}

private enum AgentBrowserToolingError: LocalizedError {
    case actionFailed(String)
    case unsupportedKey(String)

    var errorDescription: String? {
        switch self {
        case .actionFailed(let message):
            return message
        case .unsupportedKey(let key):
            return "The \(key) key is not supported by the live browser tooling yet."
        }
    }
}

private extension AgentPageObservation {
    init(_ observation: PageObservation) {
        self.init(
            title: observation.title,
            url: observation.url.flatMap { URL(string: $0) },
            visibleText: observation.visibleTextSummary,
            elements: observation.elements.map { AgentPageElement($0) }
        )
    }
}

private extension AgentPageElement {
    init(_ element: PageObservedElement) {
        self.init(
            id: element.targetID,
            role: element.kind.rawValue,
            label: element.label,
            text: element.text ?? ""
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

private extension AgentExtractionInput {
    init(_ observation: PageObservation) {
        let pageURL = observation.url.flatMap { URL(string: $0) }
        var extractionElements: [AgentExtractionElement] = []

        extractionElements.append(contentsOf: observation.links.map { AgentExtractionElement($0) })
        extractionElements.append(contentsOf: observation.buttons.map { AgentExtractionElement($0) })
        extractionElements.append(contentsOf: observation.inputs.map { AgentExtractionElement($0) })
        extractionElements.append(contentsOf: observation.forms.map { AgentExtractionElement($0) })
        extractionElements.append(contentsOf: observation.elements.map { AgentExtractionElement($0) })
        extractionElements.append(contentsOf: observation.links.compactMap { AgentExtractionElement.productCard(from: $0) })
        extractionElements.append(contentsOf: observation.links.compactMap { AgentExtractionElement.searchResult(from: $0) })

        self.init(
            url: pageURL,
            title: observation.title,
            visibleText: observation.visibleTextSummary,
            elements: extractionElements
        )
    }
}

private extension AgentExtractionElement {
    init(_ link: PageObservedLink) {
        var attributes = [
            "href": link.url ?? "",
            "class": "observed-link",
        ]
        attributes["title"] = link.title
        attributes["aria-label"] = link.ariaLabel

        self.init(
            id: link.targetID,
            tagName: "a",
            text: link.text,
            attributes: attributes
        )
    }

    init(_ button: PageObservedButton) {
        var attributes = [
            "role": "button",
            "class": "observed-button",
        ]
        attributes["type"] = button.type
        attributes["name"] = button.name
        attributes["aria-label"] = button.ariaLabel

        self.init(
            id: button.targetID,
            tagName: "button",
            text: button.text,
            attributes: attributes
        )
    }

    init(_ input: PageObservedInput) {
        var attributes = [
            "type": input.type,
            "class": input.isSearchField ? "search-field" : "observed-input",
            "aria-label": input.label,
        ]
        attributes["name"] = input.name
        attributes["placeholder"] = input.placeholder
        attributes["value"] = input.value

        self.init(
            id: input.targetID,
            tagName: "input",
            text: input.value ?? input.label,
            attributes: attributes
        )
    }

    init(_ form: PageObservedForm) {
        self.init(
            id: form.targetID,
            tagName: "form",
            text: form.label,
            attributes: [
                "action": form.action ?? "",
                "method": form.method,
                "class": form.searchFieldTargetIDs.isEmpty ? "observed-form" : "search-form",
            ]
        )
    }

    init(_ element: PageObservedElement) {
        self.init(
            id: element.targetID,
            tagName: element.kind.tagName,
            text: element.text ?? element.label,
            attributes: [
                "role": element.kind.rawValue,
                "aria-label": element.label,
                "class": "observed-\(element.kind.rawValue)",
            ]
        )
    }

    static func productCard(from link: PageObservedLink) -> AgentExtractionElement? {
        guard link.isUsefulContentCandidate else { return nil }

        let anchor = AgentExtractionElement(link)
        return AgentExtractionElement(
            id: "\(link.targetID):product",
            tagName: "div",
            text: link.text,
            attributes: [
                "class": "product-card listing observed-product",
                "role": "listitem",
            ],
            children: [anchor]
        )
    }

    static func searchResult(from link: PageObservedLink) -> AgentExtractionElement? {
        guard link.isUsefulContentCandidate else { return nil }

        let anchor = AgentExtractionElement(link)
        let snippet = AgentExtractionElement(
            id: "\(link.targetID):snippet",
            tagName: "p",
            text: link.title ?? link.ariaLabel ?? "",
            attributes: ["class": "snippet"]
        )
        return AgentExtractionElement(
            id: "\(link.targetID):result",
            tagName: "div",
            text: link.text,
            attributes: [
                "class": "search-result result observed-result",
                "role": "article",
            ],
            children: [anchor, snippet]
        )
    }
}

private extension PageObservedElementKind {
    var tagName: String {
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

private extension PageObservedLink {
    var isUsefulContentCandidate: Bool {
        let cleanedText = text.normalizedWhitespace
        guard cleanedText.count >= 4 else { return false }

        let lowercased = cleanedText.lowercased()
        let blockedTexts = [
            "account", "cart", "checkout", "filter", "help", "home", "login", "menu",
            "next", "previous", "privacy", "sign in", "sort", "terms", "wishlist",
        ]
        if blockedTexts.contains(lowercased) {
            return false
        }

        let lowerURL = (url ?? "").lowercased()
        let blockedURLParts = ["/account", "/cart", "/checkout", "/help", "/login", "/privacy", "/terms"]
        return !blockedURLParts.contains { lowerURL.contains($0) }
    }
}

private extension AgentExtractionBundle {
    var summary: String {
        [
            "\(productCards.count) product cards",
            "\(prices.count) prices",
            "\(searchResults.count) search results",
            "\(posts.count) posts",
            "\(links.count) links",
            "\(headings.count) headings",
        ].joined(separator: ", ")
    }
}

private extension String {
    var normalizedWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
