import Foundation

struct LiveAgentToolLoopRunner: AgentToolLoopRunning {
    private let resolver: AgentSiteResolver
    private let searchEngine: SearchEngine
    private let initialWaitSeconds: TimeInterval
    private let retryWaitSeconds: TimeInterval

    init(
        resolver: AgentSiteResolver = AgentSiteResolver(),
        searchEngine: SearchEngine = .google,
        initialWaitSeconds: TimeInterval = 2.0,
        retryWaitSeconds: TimeInterval = 1.0
    ) {
        self.resolver = resolver
        self.searchEngine = searchEngine
        self.initialWaitSeconds = initialWaitSeconds
        self.retryWaitSeconds = retryWaitSeconds
    }

    func run(
        request: AgentToolLoopRequest,
        browserTools: AgentBrowserTooling,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async throws -> AgentToolLoopResult {
        try Task.checkCancellation()

        let resolution = resolver.resolve(request.prompt, searchEngine: searchEngine)
        let resolveStep = await startStep(
            title: "Resolve destination",
            detail: "Routing \"\(request.prompt)\".",
            eventHandler: eventHandler
        )
        await updateStep(
            resolveStep,
            status: .completed,
            detail: "Resolved to \(resolution.kind.label): \(resolution.url.absoluteString)",
            eventHandler: eventHandler
        )

        let openStep = await startStep(
            title: "Open page",
            detail: "Opening \(resolution.url.absoluteString)",
            eventHandler: eventHandler
        )
        do {
            let openResult = try await browserTools.openURL(resolution.url)
            await updateStep(
                openStep,
                status: .completed,
                detail: openResult.summary,
                eventHandler: eventHandler
            )
        } catch {
            await updateStep(
                openStep,
                status: .failed,
                detail: "Could not open \(resolution.url.absoluteString): \(error.localizedDescription)",
                eventHandler: eventHandler
            )
            return await finish(
                "I could not open \(resolution.url.absoluteString). \(error.localizedDescription)",
                eventHandler: eventHandler
            )
        }

        let observeStep = await startStep(
            title: "Wait and observe",
            detail: "Waiting for the page to load, then reading visible content.",
            eventHandler: eventHandler
        )
        var observation = AgentPageObservation()
        do {
            _ = try await browserTools.wait(seconds: initialWaitSeconds)
            observation = try await browserTools.observePage()
            await updateStep(
                observeStep,
                status: .completed,
                detail: observedDetail(observation),
                eventHandler: eventHandler
            )
        } catch {
            await updateStep(
                observeStep,
                status: .failed,
                detail: "Could not observe the page: \(error.localizedDescription)",
                eventHandler: eventHandler
            )
            return await finish(
                "I opened \(resolution.url.absoluteString), but could not read the visible page. \(error.localizedDescription)",
                eventHandler: eventHandler
            )
        }

        let extractStep = await startStep(
            title: "Extract data",
            detail: extractionIntent(for: resolution),
            eventHandler: eventHandler
        )
        var extraction = AgentExtractionBundle()
        do {
            let result = try await browserTools.extractData(
                AgentDataExtractionRequest(
                    prompt: extractionIntent(for: resolution),
                    kinds: extractionKinds(for: resolution)
                )
            )
            extraction = result.extraction ?? AgentExtractionBundle()
        } catch {
            await updateStep(
                extractStep,
                status: .failed,
                detail: "Could not extract structured data: \(error.localizedDescription)",
                eventHandler: eventHandler
            )
            return await finish(
                finalAnswer(for: resolution, observation: observation, extraction: extraction),
                eventHandler: eventHandler
            )
        }

        if shouldRetryAfterScroll(resolution: resolution, extraction: extraction) {
            await updateStep(
                extractStep,
                status: .running,
                detail: "No useful shopping results were visible yet. Scrolling once and retrying extraction.",
                eventHandler: eventHandler
            )

            let scrollStep = await startStep(
                title: "Scroll page",
                detail: "Scrolling down once to look for loaded products.",
                eventHandler: eventHandler
            )
            do {
                let scrollResult = try await browserTools.scroll(.down)
                _ = try await browserTools.wait(seconds: retryWaitSeconds)
                observation = try await browserTools.observePage()
                let retryResult = try await browserTools.extractData(
                    AgentDataExtractionRequest(
                        prompt: extractionIntent(for: resolution),
                        kinds: extractionKinds(for: resolution)
                    )
                )
                extraction = merging(extraction, retryResult.extraction ?? AgentExtractionBundle())
                await updateStep(
                    scrollStep,
                    status: .completed,
                    detail: "\(scrollResult.summary) Retried extraction after the scroll.",
                    eventHandler: eventHandler
                )
            } catch {
                await updateStep(
                    scrollStep,
                    status: .failed,
                    detail: "Scroll retry failed: \(error.localizedDescription)",
                    eventHandler: eventHandler
                )
            }
        } else {
            let scrollStep = await startStep(
                title: "Scroll page",
                detail: "Checking whether a retry scroll is needed.",
                eventHandler: eventHandler
            )
            await updateStep(
                scrollStep,
                status: .completed,
                detail: "Visible extraction returned enough data, so no retry scroll was needed.",
                eventHandler: eventHandler
            )
        }

        await updateStep(
            extractStep,
            status: .completed,
            detail: extractionSummary(extraction),
            eventHandler: eventHandler
        )

        return await finish(
            finalAnswer(for: resolution, observation: observation, extraction: extraction),
            eventHandler: eventHandler
        )
    }
}

private extension LiveAgentToolLoopRunner {
    func startStep(
        title: String,
        detail: String,
        kind: AgentRunStepKind = .browserTool,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async -> AgentRunStep {
        let step = AgentRunStep(
            kind: kind,
            status: .running,
            title: title,
            detail: detail
        )
        await eventHandler(.stepStarted(step))
        return step
    }

    func updateStep(
        _ step: AgentRunStep,
        status: AgentRunStepStatus,
        title: String? = nil,
        detail: String,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async {
        await eventHandler(
            .stepUpdated(
                id: step.id,
                status: status,
                title: title,
                detail: detail
            )
        )
    }

    func finish(
        _ answer: String,
        eventHandler: @escaping (AgentToolLoopEvent) async -> Void
    ) async -> AgentToolLoopResult {
        let answerStep = await startStep(
            title: "Answer",
            detail: "Preparing the final response.",
            kind: .finalAnswer,
            eventHandler: eventHandler
        )
        await updateStep(
            answerStep,
            status: .completed,
            detail: answer.limited(to: 700),
            eventHandler: eventHandler
        )
        return AgentToolLoopResult(finalAnswer: answer)
    }

    func extractionKinds(for resolution: AgentSiteResolution) -> Set<AgentExtractionKind> {
        switch resolution.kind {
        case .flipkartSearch, .amazonSearch, .shoppingSearch:
            return [.productCards, .prices, .links, .searchResults]
        case .xProfile, .xSearch:
            return [.posts, .links]
        case .directURL, .webSearch:
            return [.searchResults, .headings, .links, .prices]
        }
    }

    func extractionIntent(for resolution: AgentSiteResolution) -> String {
        switch resolution.kind {
        case .flipkartSearch, .amazonSearch, .shoppingSearch:
            return "Extract visible product cards, prices, product links, and search results for \(resolution.query)."
        case .xProfile, .xSearch:
            return "Extract visible posts and links for \(resolution.query)."
        case .directURL:
            return "Extract visible headings, links, prices, and page summary from this URL."
        case .webSearch:
            return "Extract visible search results, headings, links, and useful page text for \(resolution.query)."
        }
    }

    func shouldRetryAfterScroll(
        resolution: AgentSiteResolution,
        extraction: AgentExtractionBundle
    ) -> Bool {
        guard resolution.kind.isShopping else { return false }
        return usefulProductCards(in: extraction, query: resolution.query).isEmpty &&
            extraction.prices.isEmpty &&
            usefulShoppingLinks(in: extraction, query: resolution.query).isEmpty &&
            extraction.searchResults.isEmpty
    }

    func observedDetail(_ observation: AgentPageObservation) -> String {
        let title = observation.title.nilIfBlank ?? "Untitled page"
        let source = observation.url?.absoluteString ?? "current page"
        let visibleText = observation.visibleText.normalizedWhitespace
        guard !visibleText.isEmpty else {
            return "Observed \(title) at \(source). No readable visible text was exposed yet."
        }
        return "Observed \(title) at \(source). \(visibleText.limited(to: 260))"
    }

    func extractionSummary(_ extraction: AgentExtractionBundle) -> String {
        let parts = [
            "\(extraction.productCards.count) product cards",
            "\(extraction.prices.count) prices",
            "\(extraction.searchResults.count) search results",
            "\(extraction.posts.count) posts",
            "\(extraction.links.count) links",
            "\(extraction.headings.count) headings",
        ]
        return "Extracted \(parts.joined(separator: ", "))."
    }

    func merging(
        _ lhs: AgentExtractionBundle,
        _ rhs: AgentExtractionBundle
    ) -> AgentExtractionBundle {
        AgentExtractionBundle(
            posts: lhs.posts + rhs.posts,
            prices: lhs.prices + rhs.prices,
            productCards: lhs.productCards + rhs.productCards,
            links: lhs.links + rhs.links,
            headings: lhs.headings + rhs.headings,
            tables: lhs.tables + rhs.tables,
            searchResults: lhs.searchResults + rhs.searchResults
        )
    }

    func finalAnswer(
        for resolution: AgentSiteResolution,
        observation: AgentPageObservation,
        extraction: AgentExtractionBundle
    ) -> String {
        switch resolution.kind {
        case .flipkartSearch, .amazonSearch, .shoppingSearch:
            return shoppingAnswer(for: resolution, observation: observation, extraction: extraction)
        case .xProfile, .xSearch:
            return socialAnswer(for: resolution, observation: observation, extraction: extraction)
        case .directURL, .webSearch:
            return genericAnswer(for: resolution, observation: observation, extraction: extraction)
        }
    }

    func shoppingAnswer(
        for resolution: AgentSiteResolution,
        observation: AgentPageObservation,
        extraction: AgentExtractionBundle
    ) -> String {
        let cards = usefulProductCards(in: extraction, query: resolution.query)
        let source = observation.url?.absoluteString ?? resolution.url.absoluteString

        if !cards.isEmpty {
            let lines = cards.prefix(5).map { card -> String in
                let price = card.price.flatMap { $0.text.nilIfBlank } ?? "price not visible"
                let url = card.url?.absoluteString ?? source
                return "- \(card.title.normalizedWhitespace) - \(price) (\(url))"
            }
            return """
            I found these visible shopping results for "\(resolution.query)":
            \(lines.joined(separator: "\n"))
            Source: \(source)
            """
        }

        let links = usefulShoppingLinks(in: extraction, query: resolution.query)
        let prices = uniquePrices(in: extraction)
        if !links.isEmpty || !prices.isEmpty {
            var sections: [String] = []
            if !prices.isEmpty {
                sections.append("Visible prices: \(prices.prefix(8).joined(separator: ", "))")
            }
            if !links.isEmpty {
                let linkLines = links.prefix(5).map { "- \($0.text.normalizedWhitespace) (\($0.url.absoluteString))" }
                sections.append("Visible product-like links:\n\(linkLines.joined(separator: "\n"))")
            }
            sections.append("Source: \(source)")
            return sections.joined(separator: "\n")
        }

        return """
        I opened \(resolution.kind.label) for "\(resolution.query)", but the visible page did not expose product cards or prices. The site may still be loading, blocking automation, or requiring location/login before prices appear.
        Source: \(source)
        """
    }

    func socialAnswer(
        for resolution: AgentSiteResolution,
        observation: AgentPageObservation,
        extraction: AgentExtractionBundle
    ) -> String {
        let source = observation.url?.absoluteString ?? resolution.url.absoluteString
        let posts = uniquePosts(in: extraction)
        if !posts.isEmpty {
            let lines = posts.prefix(5).map { post -> String in
                let authorPrefix = post.author.flatMap { $0.nilIfBlank }.map { "\($0): " } ?? ""
                let urlSuffix = post.url.map { " (\($0.absoluteString))" } ?? ""
                return "- \(authorPrefix)\(post.body.normalizedWhitespace.limited(to: 220))\(urlSuffix)"
            }
            return """
            I found these visible posts for "\(resolution.query)":
            \(lines.joined(separator: "\n"))
            Source: \(source)
            """
        }

        let lowerText = observation.visibleText.lowercased()
        let blocked = ["log in", "sign in", "create account", "enable javascript", "something went wrong"]
            .contains { lowerText.contains($0) }
        let reason = blocked
            ? "The visible page looks gated by login or dynamic loading."
            : "No post text was exposed in the visible page snapshot."
        let links = extraction.links
            .filter { isUsefulText($0.text) }
            .uniqueBy { $0.url.absoluteString }
            .prefix(4)
            .map { "- \($0.text.normalizedWhitespace) (\($0.url.absoluteString))" }
            .joined(separator: "\n")

        if links.isEmpty {
            return """
            I opened X for "\(resolution.query)", but could not extract visible posts. \(reason)
            Source: \(source)
            """
        }

        return """
        I opened X for "\(resolution.query)", but could not extract visible posts. \(reason)
        Visible links:
        \(links)
        Source: \(source)
        """
    }

    func genericAnswer(
        for resolution: AgentSiteResolution,
        observation: AgentPageObservation,
        extraction: AgentExtractionBundle
    ) -> String {
        let source = observation.url?.absoluteString ?? resolution.url.absoluteString
        let results = extraction.searchResults
            .filter { isUsefulText($0.title) }
            .uniqueBy { $0.url.absoluteString }

        if !results.isEmpty {
            let lines = results.prefix(5).map { result -> String in
                let snippetText = result.snippet.flatMap { $0.nilIfBlank }.map {
                    " - \($0.normalizedWhitespace.limited(to: 140))"
                } ?? ""
                return "- \(result.title.normalizedWhitespace)\(snippetText) (\(result.url.absoluteString))"
            }
            return """
            I found these visible results for "\(resolution.query)":
            \(lines.joined(separator: "\n"))
            Source: \(source)
            """
        }

        let headings = extraction.headings
            .map(\.text)
            .filter(isUsefulText)
            .unique()
            .prefix(5)
        let summary = observation.visibleText.normalizedWhitespace.limited(to: 700)
        if !headings.isEmpty {
            return """
            Visible page summary from \(source):
            \(summary)
            Headings: \(headings.joined(separator: "; "))
            """
        }

        let links = extraction.links
            .filter { isUsefulText($0.text) }
            .uniqueBy { $0.url.absoluteString }
            .prefix(5)
            .map { "- \($0.text.normalizedWhitespace) (\($0.url.absoluteString))" }
            .joined(separator: "\n")
        if !links.isEmpty {
            return """
            Visible page summary from \(source):
            \(summary)
            Useful links:
            \(links)
            """
        }

        return summary.isEmpty
            ? "I opened \(source), but the visible page did not expose readable text."
            : "Visible page summary from \(source):\n\(summary)"
    }

    func usefulProductCards(
        in extraction: AgentExtractionBundle,
        query: String
    ) -> [AgentExtractedProductCard] {
        extraction.productCards
            .filter { card in
                isUsefulText(card.title) &&
                    !isNavigationText(card.title) &&
                    (matchesQuery(card.title, url: card.url, query: query) || card.price != nil)
            }
            .uniqueBy { card in
                card.url?.absoluteString ?? "\(card.title)|\(card.price?.text ?? "")"
            }
    }

    func usefulShoppingLinks(
        in extraction: AgentExtractionBundle,
        query: String
    ) -> [AgentExtractedLink] {
        extraction.links
            .filter { link in
                isUsefulText(link.text) &&
                    !isNavigationText(link.text) &&
                    matchesQuery(link.text, url: link.url, query: query)
            }
            .uniqueBy { $0.url.absoluteString }
    }

    func uniquePrices(in extraction: AgentExtractionBundle) -> [String] {
        extraction.prices
            .map(\.text)
            .filter(isUsefulText)
            .unique()
    }

    func uniquePosts(in extraction: AgentExtractionBundle) -> [AgentExtractedPost] {
        extraction.posts.uniqueBy { post in
            post.url?.absoluteString ?? "\(post.author ?? "")|\(post.body)"
        }
    }

    func matchesQuery(_ text: String, url: URL?, query: String) -> Bool {
        let queryTokens = tokens(in: query)
        guard !queryTokens.isEmpty else { return true }
        let haystack = "\(text) \(url?.absoluteString ?? "")".lowercased()

        if queryTokens.count == 1, let token = queryTokens.first, token.count <= 3 {
            if token == "tv" {
                return haystack.contains("tv") || haystack.contains("television")
            }
            return haystack.contains(token)
        }

        return queryTokens.contains { haystack.contains($0) }
    }

    func tokens(in text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !["from", "with", "price", "buy", "shop"].contains($0) }
    }

    func isUsefulText(_ text: String) -> Bool {
        text.normalizedWhitespace.count >= 3
    }

    func isNavigationText(_ text: String) -> Bool {
        let lowercased = text.normalizedWhitespace.lowercased()
        let blocked = [
            "account", "advertising", "cart", "checkout", "filter", "help", "home", "login",
            "menu", "next", "previous", "privacy", "sign in", "sort", "terms", "wishlist",
        ]
        return blocked.contains(lowercased) || blocked.contains { lowercased.hasPrefix("\($0) ") }
    }
}

private extension AgentSiteResolution.Kind {
    var isShopping: Bool {
        switch self {
        case .flipkartSearch, .amazonSearch, .shoppingSearch:
            return true
        case .directURL, .xProfile, .xSearch, .webSearch:
            return false
        }
    }

    var label: String {
        switch self {
        case .directURL:
            return "direct URL"
        case .xProfile:
            return "X profile"
        case .xSearch:
            return "X search"
        case .flipkartSearch:
            return "Flipkart"
        case .amazonSearch:
            return "Amazon"
        case .shoppingSearch:
            return "shopping search"
        case .webSearch:
            return "web search"
        }
    }
}

private extension Array {
    func uniqueBy<Key: Hashable>(_ key: (Element) -> Key) -> [Element] {
        var seen = Set<Key>()
        return filter { seen.insert(key($0)).inserted }
    }
}

private extension Array where Element == String {
    func unique() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private extension String {
    var normalizedWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    var nilIfBlank: String? {
        let normalized = normalizedWhitespace
        return normalized.isEmpty ? nil : normalized
    }

    func limited(to limit: Int) -> String {
        guard count > limit else { return self }
        return String(prefix(limit))
    }
}
