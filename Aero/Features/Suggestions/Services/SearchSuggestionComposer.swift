import Foundation

enum SearchSuggestionComposer {
    static func recentMatches(query: String, recentSearches: [String]) -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return recentSearches }
        return recentSearches.filter { $0.localizedCaseInsensitiveContains(normalized) }
    }

    static func compose(query: String, recentSearches: [String], googleSuggestions: [String]) -> [String] {
        let matches = recentMatches(query: query, recentSearches: recentSearches)
        var merged: [String] = []
        for item in matches + googleSuggestions {
            if !merged.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                merged.append(item)
            }
        }
        return merged
    }
}

