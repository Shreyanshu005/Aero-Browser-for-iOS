import Foundation

struct DeterministicAgentToolLoopRunner: AgentToolLoopRunning {
    var searchEngine: SearchEngine
    var siteResolver: AgentSiteResolver

    init(
        searchEngine: SearchEngine = .google,
        siteResolver: AgentSiteResolver = AgentSiteResolver()
    ) {
        self.searchEngine = searchEngine
        self.siteResolver = siteResolver
    }

    func run(
        request: AgentToolLoopRequest,
        browserTools: AgentBrowserTooling,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult {
        try Task.checkCancellation()

        let planStep = AgentRunStep(
            kind: .run,
            status: .running,
            title: "Resolve task",
            detail: "Choosing deterministic browser steps."
        )
        await eventHandler(.stepStarted(planStep))

        let resolution = siteResolver.resolve(request.prompt, searchEngine: searchEngine)
        await eventHandler(
            .stepUpdated(
                id: planStep.id,
                status: .completed,
                title: nil,
                detail: "Prepared \(description(for: resolution.kind))."
            )
        )

        var navigationSummary: String?
        if shouldNavigate(for: request.prompt, resolution: resolution) {
            let openStep = AgentRunStep(
                kind: .browserTool,
                status: .running,
                title: "Open page",
                detail: resolution.url.absoluteString
            )
            await eventHandler(.stepStarted(openStep))

            let result = try await browserTools.openURL(resolution.url)
            navigationSummary = result.summary
            await eventHandler(
                .stepUpdated(
                    id: openStep.id,
                    status: .completed,
                    title: nil,
                    detail: result.summary
                )
            )

            _ = try await browserTools.wait(seconds: 1)
        }

        try Task.checkCancellation()

        let approval = AgentApprovalRequest(
            kind: .pageAccess,
            title: "Allow page access",
            detail: "Read the visible page so the agent can continue this task."
        )
        await eventHandler(.approvalRequested(approval))
        let decision = await browserTools.requestApproval(approval)
        await eventHandler(.approvalResolved(approval, decision))
        guard decision == .approved else {
            throw DeterministicAgentToolLoopRunnerError.approvalDenied
        }

        try Task.checkCancellation()

        let observeStep = AgentRunStep(
            kind: .browserTool,
            status: .running,
            title: "Observe page",
            detail: "Reading visible page content."
        )
        await eventHandler(.stepStarted(observeStep))

        let observation = try await browserTools.observePage()
        await eventHandler(
            .stepUpdated(
                id: observeStep.id,
                status: .completed,
                title: nil,
                detail: observationSummary(observation)
            )
        )

        var extractionSummary: String?
        if shouldExtractData(for: request.prompt) {
            let extractionStep = AgentRunStep(
                kind: .browserTool,
                status: .running,
                title: "Extract data",
                detail: "Collecting structured page details."
            )
            await eventHandler(.stepStarted(extractionStep))

            let result = try await browserTools.extractData(
                AgentDataExtractionRequest(prompt: request.prompt)
            )
            extractionSummary = result.summary
            await eventHandler(
                .stepUpdated(
                    id: extractionStep.id,
                    status: .completed,
                    title: nil,
                    detail: result.summary
                )
            )
        }

        return AgentToolLoopResult(
            finalAnswer: finalAnswer(
                prompt: request.prompt,
                observation: observation,
                navigationSummary: navigationSummary,
                extractionSummary: extractionSummary
            )
        )
    }

    private func shouldNavigate(
        for prompt: String,
        resolution: AgentSiteResolution
    ) -> Bool {
        if case .url = URLInput.classify(prompt) {
            return true
        }

        switch resolution.kind {
        case .directURL, .xProfile, .xSearch, .flipkartSearch, .amazonSearch, .shoppingSearch:
            return true
        case .webSearch:
            let tokens = tokens(in: prompt)
            return !tokens.isDisjoint(with: [
                "find", "go", "latest", "look", "lookup", "open", "search", "show", "visit",
            ])
        }
    }

    private func shouldExtractData(for prompt: String) -> Bool {
        let tokens = tokens(in: prompt)
        return !tokens.isDisjoint(with: [
            "extract", "headings", "links", "prices", "products", "results", "tables",
        ])
    }

    private func observationSummary(_ observation: AgentPageObservation) -> String {
        let title = observation.title.isEmpty ? "Untitled page" : observation.title
        let elementCount = observation.elements.count
        let textState = observation.visibleText.isEmpty ? "no readable text" : "visible text"
        return "Observed \(title) with \(elementCount) elements and \(textState)."
    }

    private func finalAnswer(
        prompt: String,
        observation: AgentPageObservation,
        navigationSummary: String?,
        extractionSummary: String?
    ) -> String {
        var lines = ["Task: \(prompt)"]

        if let navigationSummary {
            lines.append(navigationSummary)
        }

        if !observation.title.isEmpty {
            lines.append("Page: \(observation.title)")
        }

        if let url = observation.url {
            lines.append("URL: \(url.absoluteString)")
        }

        let pageText = compact(observation.visibleText, limit: 900)
        if pageText.isEmpty {
            lines.append("I observed the page, but there was no readable visible text.")
        } else {
            lines.append("Visible page text:\n\(pageText)")
        }

        let elements = observation.elements
            .prefix(5)
            .map { element -> String in
                let label = element.label.isEmpty ? element.text : element.label
                return "- \(element.role): \(compact(label, limit: 120))"
            }
            .filter { !$0.hasSuffix(": ") }

        if !elements.isEmpty {
            lines.append("Visible targets:\n\(elements.joined(separator: "\n"))")
        }

        if let extractionSummary, !extractionSummary.isEmpty {
            lines.append("Structured data:\n\(extractionSummary)")
        }

        return lines.joined(separator: "\n\n")
    }

    private func description(for kind: AgentSiteResolution.Kind) -> String {
        switch kind {
        case .directURL:
            return "a direct URL"
        case .xProfile:
            return "an X profile lookup"
        case .xSearch:
            return "an X search"
        case .flipkartSearch:
            return "a Flipkart search"
        case .amazonSearch:
            return "an Amazon search"
        case .shoppingSearch:
            return "a shopping search"
        case .webSearch:
            return "a page review"
        }
    }

    private func tokens(in text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
    }

    private func compact(_ text: String, limit: Int) -> String {
        let cleaned = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > limit else { return cleaned }
        return "\(cleaned.prefix(limit))..."
    }
}

private enum DeterministicAgentToolLoopRunnerError: LocalizedError {
    case approvalDenied

    var errorDescription: String? {
        switch self {
        case .approvalDenied:
            return "Approval was denied."
        }
    }
}
