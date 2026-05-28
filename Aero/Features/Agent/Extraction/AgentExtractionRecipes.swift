import Foundation

enum AgentExtractionRecipes {
    static let all: [AgentExtractionRecipe] = [
        AgentPostExtractionRecipe(),
        AgentPriceExtractionRecipe(),
        AgentProductCardExtractionRecipe(),
        AgentLinkExtractionRecipe(),
        AgentHeadingExtractionRecipe(),
        AgentTableExtractionRecipe(),
        AgentSearchResultExtractionRecipe(),
    ]
}

struct AgentLinkExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .links

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var seen = Set<String>()
        let links = input.allElements.compactMap { element -> AgentExtractedLink? in
            guard element.normalizedTagName == "a",
                  let href = element.attribute("href"),
                  let url = input.resolvedURL(from: href),
                  seen.insert(url.absoluteString).inserted else {
                return nil
            }

            let text = element.bestText(fallbackAttributes: ["aria-label", "title"])
                .nilIfEmpty ?? url.absoluteString

            return AgentExtractedLink(
                text: text,
                url: url,
                rel: element.attribute("rel"),
                source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.92)
            )
        }

        return .links(links)
    }
}

struct AgentHeadingExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .headings

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var seen = Set<String>()
        let headings = input.allElements.compactMap { element -> AgentExtractedHeading? in
            guard let level = headingLevel(for: element) else { return nil }

            let text = element.bestText(fallbackAttributes: ["aria-label", "title"])
            guard !text.isEmpty, seen.insert("\(level)|\(text)").inserted else { return nil }

            return AgentExtractedHeading(
                level: level,
                text: text,
                source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.94)
            )
        }

        return .headings(headings)
    }

    private func headingLevel(for element: AgentExtractionElement) -> Int? {
        let tagName = element.normalizedTagName

        if tagName.count == 2,
           tagName.first == "h",
           let level = Int(String(tagName.suffix(1))),
           (1...6).contains(level) {
            return level
        }

        guard element.attribute("role")?.caseInsensitiveCompare("heading") == .orderedSame else {
            return nil
        }

        if let ariaLevel = element.attribute("aria-level"), let level = Int(ariaLevel), (1...6).contains(level) {
            return level
        }

        return 2
    }
}

struct AgentPriceExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .prices

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var prices: [AgentExtractedPrice] = []
        var seen = Set<String>()

        for element in input.allElements {
            let text = element.bestText(fallbackAttributes: ["aria-label", "title"])
            let hintConfidence = element.hasAnyExtractionToken(["price", "amount", "sale", "discount", "cost"])
            appendPrices(
                from: text,
                source: AgentExtractionSource(
                    elementID: element.id,
                    tagName: element.tagName,
                    confidence: hintConfidence ? 0.88 : 0.62
                ),
                seen: &seen,
                prices: &prices
            )
        }

        appendPrices(
            from: input.visibleText,
            source: AgentExtractionSource(confidence: 0.45),
            seen: &seen,
            prices: &prices
        )

        return .prices(prices)
    }
}

struct AgentProductCardExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .productCards

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var seen = Set<String>()
        let cards = input.allElements.compactMap { element -> AgentExtractedProductCard? in
            guard element.looksLikeProductContainer else { return nil }

            let price = firstPrice(in: element)
            guard let title = productTitle(in: element, excluding: price?.text),
                  price != nil || element.firstResolvedLink(in: input) != nil || element.firstImageURL(in: input) != nil else {
                return nil
            }

            let url = element.firstResolvedLink(in: input)
            let imageURL = element.firstImageURL(in: input)
            let key = url?.absoluteString ?? "\(title)|\(price?.text ?? "")"
            guard seen.insert(key).inserted else { return nil }

            return AgentExtractedProductCard(
                title: title,
                price: price,
                url: url,
                imageURL: imageURL,
                source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: price == nil ? 0.68 : 0.86)
            )
        }

        return .productCards(cards)
    }

    private func productTitle(in element: AgentExtractionElement, excluding priceText: String?) -> String? {
        let titleTokens = ["title", "name", "product-name", "product-title", "item-title"]
        let preferred = element.descendants.first { descendant in
            descendant.attribute("itemprop")?.caseInsensitiveCompare("name") == .orderedSame ||
                descendant.hasAnyExtractionToken(titleTokens) ||
                ["h1", "h2", "h3", "h4"].contains(descendant.normalizedTagName)
        }

        let title = preferred?.bestText(fallbackAttributes: ["aria-label", "title"])
            ?? element.descendants.first(where: { $0.normalizedTagName == "a" })?.bestText(fallbackAttributes: ["aria-label", "title"])

        return title?
            .removingSuffix(priceText)
            .nilIfEmpty
    }

    private func firstPrice(in element: AgentExtractionElement) -> AgentExtractedPrice? {
        let priceElements = element.descendants.filter {
            $0.hasAnyExtractionToken(["price", "amount", "sale", "discount", "cost"])
        }

        for priceElement in priceElements {
            if let price = extractFirstPrice(
                from: priceElement.bestText(fallbackAttributes: ["aria-label", "title"]),
                source: AgentExtractionSource(elementID: priceElement.id, tagName: priceElement.tagName, confidence: 0.9)
            ) {
                return price
            }
        }

        return extractFirstPrice(
            from: element.bestText(fallbackAttributes: ["aria-label", "title"]),
            source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.68)
        )
    }
}

struct AgentPostExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .posts

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var seen = Set<String>()
        let posts = input.allElements.compactMap { element -> AgentExtractedPost? in
            guard element.looksLikePostContainer else { return nil }

            let body = postBody(in: element)
            guard body.count >= 8 else { return nil }

            let author = postAuthor(in: element)
            let timestamp = postTimestamp(in: element)
            let url = postURL(in: element, input: input)
            let key = url?.absoluteString ?? "\(author ?? "")|\(body)"
            guard seen.insert(key).inserted else { return nil }

            return AgentExtractedPost(
                author: author,
                body: body,
                timestamp: timestamp,
                url: url,
                source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.82)
            )
        }

        return .posts(posts)
    }

    private func postAuthor(in element: AgentExtractionElement) -> String? {
        if let dataAuthor = element.attribute("data-author")?.normalizedWhitespace.nilIfEmpty {
            return dataAuthor
        }

        return element.descendants.first { descendant in
            descendant.attribute("rel")?.caseInsensitiveCompare("author") == .orderedSame ||
                descendant.hasAnyExtractionToken(["author", "username", "user-name", "byline", "screen-name"])
        }?.bestText(fallbackAttributes: ["aria-label", "title"]).nilIfEmpty
    }

    private func postBody(in element: AgentExtractionElement) -> String {
        let bodyTokens = ["body", "content", "text", "message", "caption", "post-text", "tweet-text"]
        let body = element.descendants.first {
            $0.hasAnyExtractionToken(bodyTokens) && !$0.bestText(fallbackAttributes: []).isEmpty
        }?.bestText(fallbackAttributes: [])

        if let body = body?.nilIfEmpty {
            return body
        }

        let paragraphs = element.descendants
            .filter { ["p", "blockquote"].contains($0.normalizedTagName) }
            .map { $0.bestText(fallbackAttributes: []) }
            .filter { !$0.isEmpty }

        return (paragraphs.isEmpty ? element.bestText(fallbackAttributes: []) : paragraphs.joined(separator: "\n"))
            .normalizedWhitespace
    }

    private func postTimestamp(in element: AgentExtractionElement) -> String? {
        element.descendants.first(where: { $0.normalizedTagName == "time" })?
            .attribute("datetime", "title")
            .flatMap { $0.normalizedWhitespace.nilIfEmpty }
            ?? element.descendants.first(where: { $0.hasAnyExtractionToken(["timestamp", "time", "date"]) })?
            .bestText(fallbackAttributes: ["datetime", "title"])
            .nilIfEmpty
    }

    private func postURL(in element: AgentExtractionElement, input: AgentExtractionInput) -> URL? {
        let permalink = element.descendants.first {
            $0.normalizedTagName == "a" &&
                $0.hasAnyExtractionToken(["permalink", "status", "post", "tweet", "time"])
        }?.attribute("href")

        if let permalink, let url = input.resolvedURL(from: permalink, allowedSchemes: ["http", "https"]) {
            return url
        }

        return element.firstResolvedLink(in: input)
    }
}

struct AgentTableExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .tables

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        var tables: [AgentExtractedTable] = []

        for element in input.allElements {
            if element.normalizedTagName == "table", let table = nativeTable(from: element) {
                tables.append(table)
            } else if element.attribute("role").map({ ["table", "grid"].contains($0.lowercased()) }) == true,
                      let table = ariaTable(from: element) {
                tables.append(table)
            }
        }

        return .tables(tables)
    }

    private func nativeTable(from element: AgentExtractionElement) -> AgentExtractedTable? {
        let rows = element.descendants
            .filter { $0.normalizedTagName == "tr" }
            .map { row in
                row.children
                    .filter { ["th", "td"].contains($0.normalizedTagName) }
                    .map { $0.bestText(fallbackAttributes: ["aria-label", "title"]) }
                    .filter { !$0.isEmpty }
            }
            .filter { !$0.isEmpty }

        guard !rows.isEmpty else { return nil }

        let headerRow = element.descendants
            .first { $0.normalizedTagName == "tr" && $0.children.contains(where: { $0.normalizedTagName == "th" }) }

        let headers = headerRow?.children
            .filter { ["th", "td"].contains($0.normalizedTagName) }
            .map { $0.bestText(fallbackAttributes: ["aria-label", "title"]) }
            .filter { !$0.isEmpty } ?? []

        let bodyRows = rows.dropFirst(headers.isEmpty ? 0 : 1)

        return AgentExtractedTable(
            caption: element.children.first(where: { $0.normalizedTagName == "caption" })?.bestText(fallbackAttributes: []).nilIfEmpty,
            headers: headers,
            rows: Array(bodyRows),
            source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.9)
        )
    }

    private func ariaTable(from element: AgentExtractionElement) -> AgentExtractedTable? {
        let rowElements = element.descendants.filter {
            $0.attribute("role")?.caseInsensitiveCompare("row") == .orderedSame
        }

        let rows = rowElements.map { row in
            row.children
                .filter {
                    guard let role = $0.attribute("role")?.lowercased() else { return false }
                    return ["cell", "gridcell", "columnheader", "rowheader"].contains(role)
                }
                .map { $0.bestText(fallbackAttributes: ["aria-label", "title"]) }
                .filter { !$0.isEmpty }
        }
        .filter { !$0.isEmpty }

        guard !rows.isEmpty else { return nil }

        let headerRow = rowElements.first { row in
            row.children.contains {
                let role = $0.attribute("role")?.lowercased()
                return role == "columnheader" || role == "rowheader"
            }
        }

        let headers = headerRow?.children
            .filter {
                let role = $0.attribute("role")?.lowercased()
                return role == "columnheader" || role == "rowheader"
            }
            .map { $0.bestText(fallbackAttributes: ["aria-label", "title"]) }
            .filter { !$0.isEmpty } ?? []

        return AgentExtractedTable(
            caption: element.attribute("aria-label").flatMap { $0.normalizedWhitespace.nilIfEmpty },
            headers: headers,
            rows: Array(rows.dropFirst(headers.isEmpty ? 0 : 1)),
            source: AgentExtractionSource(elementID: element.id, tagName: element.tagName, confidence: 0.78)
        )
    }
}

struct AgentSearchResultExtractionRecipe: AgentExtractionRecipe {
    let kind: AgentExtractionKind = .searchResults

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult {
        let searchContext = input.looksLikeSearchPage
        var seen = Set<String>()

        let results = input.allElements.compactMap { element -> AgentExtractedSearchResult? in
            guard searchContext || element.looksLikeSearchResultContainer else { return nil }
            guard let anchor = element.descendants.first(where: { candidate in
                candidate.normalizedTagName == "a" &&
                    candidate.bestText(fallbackAttributes: ["aria-label", "title"]).count >= 3 &&
                    candidate.attribute("href").flatMap {
                        input.resolvedURL(from: $0, allowedSchemes: ["http", "https"])
                    } != nil
            }),
                let href = anchor.attribute("href"),
                let url = input.resolvedURL(from: href, allowedSchemes: ["http", "https"]),
                seen.insert(url.absoluteString).inserted else {
                return nil
            }

            let title = anchor.bestText(fallbackAttributes: ["aria-label", "title"])
            let snippet = searchSnippet(in: element, excluding: title)

            return AgentExtractedSearchResult(
                title: title,
                url: url,
                snippet: snippet,
                source: AgentExtractionSource(
                    elementID: element.id,
                    tagName: element.tagName,
                    confidence: element.looksLikeSearchResultContainer ? 0.86 : 0.66
                )
            )
        }

        return .searchResults(results)
    }

    private func searchSnippet(in element: AgentExtractionElement, excluding title: String) -> String? {
        let snippetTokens = ["snippet", "description", "summary", "excerpt", "abstract"]

        let preferred = element.descendants.first {
            $0.hasAnyExtractionToken(snippetTokens) &&
                $0.bestText(fallbackAttributes: []).nilIfEmpty != nil
        }?.bestText(fallbackAttributes: [])

        if let preferred = preferred?.nilIfEmpty {
            return preferred
        }

        return element.descendants
            .filter { ["p", "span"].contains($0.normalizedTagName) }
            .map { $0.bestText(fallbackAttributes: []) }
            .first {
                !$0.isEmpty &&
                    $0 != title &&
                    !$0.hasPrefix("http://") &&
                    !$0.hasPrefix("https://")
            }
    }
}

private func appendPrices(
    from text: String,
    source: AgentExtractionSource,
    seen: inout Set<String>,
    prices: inout [AgentExtractedPrice]
) {
    for price in extractPrices(from: text, source: source) {
        guard seen.insert("\(price.text)|\(source.elementID ?? "")").inserted else { continue }
        prices.append(price)
    }
}

private func extractFirstPrice(
    from text: String,
    source: AgentExtractionSource
) -> AgentExtractedPrice? {
    extractPrices(from: text, source: source).first
}

private func extractPrices(
    from text: String,
    source: AgentExtractionSource
) -> [AgentExtractedPrice] {
    let normalized = text.normalizedWhitespace
    guard !normalized.isEmpty else { return [] }

    let matches = AgentPricePattern.expression.matches(
        in: normalized,
        options: [],
        range: NSRange(location: 0, length: (normalized as NSString).length)
    )

    return matches.compactMap { match in
        guard let matchRange = Range(match.range, in: normalized) else { return nil }

        let priceText = String(normalized[matchRange]).normalizedWhitespace
        let symbol = normalized.substring(for: match.range(at: 1))
        let prefixedAmount = normalized.substring(for: match.range(at: 2))
        let suffixedAmount = normalized.substring(for: match.range(at: 3))
        let code = normalized.substring(for: match.range(at: 4))
        let currency = symbol.flatMap { AgentPricePattern.currencySymbols[$0] } ?? code?.uppercased()
        let amount = Decimal(string: (prefixedAmount ?? suffixedAmount ?? "").replacingOccurrences(of: ",", with: ""))

        return AgentExtractedPrice(
            text: priceText,
            currency: currency,
            amount: amount,
            source: source
        )
    }
}

private enum AgentPricePattern {
    static let expression = try! NSRegularExpression(
        pattern: #"(?:([$€£¥₹])\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s?(USD|EUR|GBP|JPY|INR|CAD|AUD))"#,
        options: [.caseInsensitive]
    )

    static let currencySymbols = [
        "$": "USD",
        "€": "EUR",
        "£": "GBP",
        "¥": "JPY",
        "₹": "INR",
    ]
}

private extension AgentExtractionInput {
    var allElements: [AgentExtractionElement] {
        elements.flatMap { [$0] + $0.descendants }
    }

    var looksLikeSearchPage: Bool {
        let haystack = [
            url?.host,
            url?.path,
            url?.query,
            title,
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        return haystack.contains("search") ||
            haystack.contains("result") ||
            haystack.contains("q=") ||
            haystack.contains("query=")
    }

    func resolvedURL(
        from value: String,
        allowedSchemes: Set<String> = ["http", "https", "mailto", "tel"]
    ) -> URL? {
        let trimmed = value.normalizedWhitespace
        guard !trimmed.isEmpty, trimmed != "#" else { return nil }

        let lowercased = trimmed.lowercased()
        guard !lowercased.hasPrefix("javascript:"),
              !lowercased.hasPrefix("data:"),
              !lowercased.hasPrefix("blob:") else {
            return nil
        }

        guard let url = URL(string: trimmed, relativeTo: self.url)?.absoluteURL,
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            return nil
        }

        return url
    }
}

private extension AgentExtractionElement {
    var normalizedTagName: String {
        tagName.lowercased()
    }

    var descendants: [AgentExtractionElement] {
        children.flatMap { [$0] + $0.descendants }
    }

    var looksLikeProductContainer: Bool {
        hasAnyExtractionToken(["product", "product-card", "product-tile", "listing", "sku", "item-card"]) ||
            attribute("itemtype")?.lowercased().contains("product") == true ||
            (attribute("role")?.lowercased() == "listitem" && descendants.contains { $0.hasAnyExtractionToken(["price", "amount"]) })
    }

    var looksLikePostContainer: Bool {
        normalizedTagName == "article" ||
            attribute("role")?.lowercased() == "article" ||
            hasAnyExtractionToken(["post", "tweet", "status", "feed-item", "comment", "timeline-item"])
    }

    var looksLikeSearchResultContainer: Bool {
        hasAnyExtractionToken(["search-result", "result", "serp-result", "organic-result", "web-result"]) ||
            attribute("role")?.lowercased() == "article"
    }

    func attribute(_ names: String...) -> String? {
        for name in names {
            if let value = attributes[name]?.normalizedWhitespace.nilIfEmpty {
                return value
            }

            if let pair = attributes.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame }),
               let value = pair.value.normalizedWhitespace.nilIfEmpty {
                return value
            }
        }

        return nil
    }

    func bestText(fallbackAttributes: [String]) -> String {
        if let text = text.normalizedWhitespace.nilIfEmpty {
            return text
        }

        for attributeName in fallbackAttributes {
            if let value = attribute(attributeName) {
                return value
            }
        }

        return children
            .map { $0.bestText(fallbackAttributes: fallbackAttributes) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .normalizedWhitespace
    }

    func hasAnyExtractionToken(_ tokens: [String]) -> Bool {
        let haystack = [
            id,
            attribute("class"),
            attribute("id"),
            attribute("role"),
            attribute("itemprop"),
            attribute("aria-label"),
            attribute("data-testid"),
            attribute("data-test"),
        ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()

        return tokens.contains { haystack.contains($0.lowercased()) }
    }

    func firstResolvedLink(in input: AgentExtractionInput) -> URL? {
        descendants.lazy
            .filter { $0.normalizedTagName == "a" }
            .compactMap { $0.attribute("href") }
            .compactMap { input.resolvedURL(from: $0, allowedSchemes: ["http", "https"]) }
            .first
    }

    func firstImageURL(in input: AgentExtractionInput) -> URL? {
        descendants.lazy
            .filter { $0.normalizedTagName == "img" }
            .compactMap { $0.attribute("src", "data-src", "data-original", "srcset") }
            .compactMap { source in
                let sourceSetItem = source.split(separator: ",").first.map(String.init) ?? source
                let firstSource = sourceSetItem.split(separator: " ").first.map(String.init) ?? sourceSetItem
                return input.resolvedURL(from: firstSource, allowedSchemes: ["http", "https"])
            }
            .first
    }
}

private extension String {
    var normalizedWhitespace: String {
        components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func removingSuffix(_ suffix: String?) -> String {
        guard let suffix = suffix?.nilIfEmpty, hasSuffix(suffix) else {
            return normalizedWhitespace
        }

        return String(dropLast(suffix.count)).normalizedWhitespace
    }

    func substring(for range: NSRange) -> String? {
        guard range.location != NSNotFound, let stringRange = Range(range, in: self) else {
            return nil
        }

        return String(self[stringRange])
    }
}
