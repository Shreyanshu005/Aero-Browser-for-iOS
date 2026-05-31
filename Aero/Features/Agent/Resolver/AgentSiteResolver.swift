import Foundation

struct AgentSiteResolution: Equatable {
    enum Kind: Equatable {
        case directURL
        case xProfile
        case xSearch
        case flipkartSearch
        case amazonSearch
        case shoppingSearch
        case webSearch
    }

    let kind: Kind
    let url: URL
    let query: String
}

struct AgentSiteResolver {
    func resolve(_ task: String, currentURL: URL? = nil, searchEngine: SearchEngine = .google) -> AgentSiteResolution {
        let query = Self.cleanWhitespace(task)

        let lowercased = query.lowercased()
        if let currentURL = currentURL,
           (lowercased.contains("this page") || lowercased.contains("current page") || lowercased.contains("here") || lowercased.contains("summarize this") || lowercased.contains("this site") || lowercased.contains("read this") || lowercased.contains("extract")) {
            return AgentSiteResolution(kind: .directURL, url: currentURL, query: query)
        }

        if case .url(let url) = URLInput.classify(query) {
            return AgentSiteResolution(kind: .directURL, url: url, query: query)
        }

        let tokens = Self.tokens(in: query)

        if Self.isXRequest(query, tokens: tokens) {
            if tokens.contains("elon") || tokens.contains("elonmusk") {
                return AgentSiteResolution(
                    kind: .xProfile,
                    url: URL(string: "https://x.com/elonmusk")!,
                    query: "Elon Musk"
                )
            }

            let xQuery = Self.cleanQuery(query, removing: Self.xStopWords)
            return AgentSiteResolution(
                kind: .xSearch,
                url: Self.queryURL("https://x.com/search", itemName: "q", value: xQuery),
                query: xQuery
            )
        }

        if let site = Self.shoppingSite(in: query) {
            let productQuery = Self.productQuery(query)
            return AgentSiteResolution(
                kind: site.kind,
                url: Self.queryURL(site.baseURL, itemName: site.queryItemName, value: productQuery),
                query: productQuery
            )
        }

        if !tokens.isDisjoint(with: Self.shoppingIntentWords) {
            let productQuery = Self.productQuery(query)
            return Self.searchResolution(kind: .shoppingSearch, query: productQuery, searchEngine: searchEngine)
        }

        return Self.searchResolution(kind: .webSearch, query: query, searchEngine: searchEngine)
    }
}

private extension AgentSiteResolver {
    enum ShoppingSite {
        case flipkart
        case amazon

        var kind: AgentSiteResolution.Kind {
            switch self {
            case .flipkart: return .flipkartSearch
            case .amazon: return .amazonSearch
            }
        }

        var baseURL: String {
            switch self {
            case .flipkart: return "https://www.flipkart.com/search"
            case .amazon: return "https://www.amazon.com/s"
            }
        }

        var queryItemName: String {
            switch self {
            case .flipkart: return "q"
            case .amazon: return "k"
            }
        }
    }

    static let shoppingIntentWords: Set<String> = [
        "buy", "cost", "costs", "deal", "deals", "price", "prices", "shop", "shopping",
    ]

    static let shoppingStopWords: Set<String> = shoppingIntentWords.union([
        "a", "an", "amazon", "at", "find", "flipkart", "for", "from", "in", "look",
        "lookup", "me", "on", "please", "search", "show", "the", "up",
    ])

    static let xContextWords: Set<String> = [
        "account", "elon", "handle", "post", "posted", "posts", "profile", "tweet", "tweets",
    ]

    static let xStopWords: Set<String> = [
        "at", "by", "find", "from", "in", "latest", "look", "lookup", "me", "on",
        "please", "post", "posts", "search", "show", "tweet", "tweets", "twitter", "up", "x",
    ]

    static func cleanWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    static func tokens(in text: String) -> Set<String> {
        Set(
            text
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
    }

    static func isXRequest(_ query: String, tokens: Set<String>) -> Bool {
        if tokens.contains("twitter") || tokens.contains("tweet") || tokens.contains("tweets") {
            return true
        }

        if query.lowercased().contains("x.com") {
            return true
        }

        return tokens.contains("x") && !tokens.isDisjoint(with: xContextWords)
    }

    static func shoppingSite(in query: String) -> ShoppingSite? {
        let lowercased = query.lowercased()
        let flipkart = lowercased.range(of: "flipkart")?.lowerBound
        let amazon = lowercased.range(of: "amazon")?.lowerBound

        switch (flipkart, amazon) {
        case let (flipkart?, amazon?): return flipkart < amazon ? .flipkart : .amazon
        case (.some, .none): return .flipkart
        case (.none, .some): return .amazon
        case (.none, .none): return nil
        }
    }

    static func productQuery(_ query: String) -> String {
        cleanQuery(query, removing: shoppingStopWords)
    }

    static func cleanQuery(_ query: String, removing stopWords: Set<String>) -> String {
        let parts = query.split(whereSeparator: { $0.isWhitespace }).compactMap { rawPart -> String? in
            let trimmed = String(rawPart).trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            guard !trimmed.isEmpty else { return nil }

            let normalizedParts = trimmed
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }

            return normalizedParts.contains(where: stopWords.contains) ? nil : trimmed
        }

        let cleaned = parts.joined(separator: " ")
        return cleaned.isEmpty ? query : cleaned
    }

    static func searchResolution(
        kind: AgentSiteResolution.Kind,
        query: String,
        searchEngine: SearchEngine
    ) -> AgentSiteResolution {
        AgentSiteResolution(
            kind: kind,
            url: searchEngine.searchURL(for: query) ?? searchEngine.homepageURL,
            query: query
        )
    }

    static func queryURL(_ baseURL: String, itemName: String, value: String) -> URL {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [URLQueryItem(name: itemName, value: value)]
        return components.url!
    }
}
