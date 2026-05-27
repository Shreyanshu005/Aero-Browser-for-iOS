import Foundation

struct LocalSuggestionProvider {
    private struct Candidate {
        let suggestion: BrowserSuggestion
        let score: Double
        let sourcePriority: Int
    }

    func suggestions(
        for query: String,
        tabs: [Tab],
        favorites: [FavoriteItem],
        history: [HistoryItem],
        activeTabID: UUID?,
        limit: Int = 5
    ) -> [BrowserSuggestion] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        var candidates: [Candidate] = []
        var seenURLs: Set<String> = []

        for tab in tabs where tab.id != activeTabID {
            guard let url = tab.url else { continue }
            guard let score = matchScore(query: normalizedQuery, title: tab.displayTitle, url: url) else { continue }
            let key = normalizedURLKey(url)
            guard !seenURLs.contains(key) else { continue }
            seenURLs.insert(key)
            candidates.append(
                Candidate(
                    suggestion: BrowserSuggestion(
                        id: "tab-\(tab.id.uuidString)",
                        kind: .tab,
                        title: tab.displayTitle,
                        subtitle: "Switch to Tab - \(url.displayHost ?? url.absoluteString)",
                        url: url,
                        tabID: tab.id
                    ),
                    score: 300 + score + recencyScore(tab.lastAccessedAt),
                    sourcePriority: 0
                )
            )
        }

        for favorite in favorites {
            let key = normalizedURLKey(favorite.url)
            guard !seenURLs.contains(key) else { continue }
            guard let score = matchScore(query: normalizedQuery, title: favorite.title, url: favorite.url) else { continue }
            seenURLs.insert(key)
            candidates.append(
                Candidate(
                    suggestion: BrowserSuggestion(
                        id: "favorite-\(favorite.id.uuidString)",
                        kind: .favorite,
                        title: favorite.title,
                        subtitle: favorite.url.displayHost ?? favorite.url.absoluteString,
                        url: favorite.url,
                        tabID: nil
                    ),
                    score: 200 + score,
                    sourcePriority: 1
                )
            )
        }

        for summary in historySummaries(from: history) {
            guard !seenURLs.contains(summary.key) else { continue }
            guard let score = matchScore(query: normalizedQuery, title: summary.title, url: summary.url) else { continue }
            seenURLs.insert(summary.key)
            candidates.append(
                Candidate(
                    suggestion: BrowserSuggestion(
                        id: "history-\(summary.key)",
                        kind: .history,
                        title: summary.title,
                        subtitle: summary.url.displayHost ?? summary.url.absoluteString,
                        url: summary.url,
                        tabID: nil
                    ),
                    score: 100 + score + recencyScore(summary.latestVisitDate) + Double(summary.visitCount) * 4,
                    sourcePriority: 2
                )
            )
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.sourcePriority < rhs.sourcePriority
            }
            .prefix(limit)
            .map(\.suggestion)
    }

    private struct HistorySummary {
        let key: String
        let url: URL
        let title: String
        let latestVisitDate: Date
        let visitCount: Int
    }

    private func historySummaries(from items: [HistoryItem]) -> [HistorySummary] {
        var summaries: [String: HistorySummary] = [:]

        for item in items {
            let key = normalizedURLKey(item.url)
            if let existing = summaries[key] {
                let latestItem = item.visitDate > existing.latestVisitDate ? item : nil
                summaries[key] = HistorySummary(
                    key: key,
                    url: latestItem?.url ?? existing.url,
                    title: latestItem?.title ?? existing.title,
                    latestVisitDate: max(item.visitDate, existing.latestVisitDate),
                    visitCount: existing.visitCount + 1
                )
            } else {
                summaries[key] = HistorySummary(
                    key: key,
                    url: item.url,
                    title: item.title,
                    latestVisitDate: item.visitDate,
                    visitCount: 1
                )
            }
        }

        return Array(summaries.values)
    }

    private func matchScore(query: String, title: String, url: URL) -> Double? {
        let title = normalize(title)
        let host = normalize(url.displayHost ?? "")
        let absoluteURL = normalize(url.absoluteString)

        if title.hasPrefix(query) { return 80 }
        if host.hasPrefix(query) { return 72 }
        if title.contains(query) { return 48 }
        if host.contains(query) { return 42 }
        if absoluteURL.contains(query) { return 24 }
        return nil
    }

    private func recencyScore(_ date: Date) -> Double {
        let hours = max(0, Date().timeIntervalSince(date) / 3600)
        return max(0, 24 - min(hours, 24))
    }

    private func normalizedURLKey(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let lowercasedScheme = components?.scheme?.lowercased()
        let lowercasedHost = components?.host?.lowercased()
        components?.scheme = lowercasedScheme
        components?.host = lowercasedHost

        var value = components?.url?.absoluteString.lowercased() ?? url.absoluteString.lowercased()
        if value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
