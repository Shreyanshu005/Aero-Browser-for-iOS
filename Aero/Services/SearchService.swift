import Foundation

@Observable
final class SearchService {
    var searchSuggestions: [String] = []
    var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
    private var suggestionsTask: Task<Void, Never>?
    
    func fetchSearchSuggestions(for query: String, isFocused: Bool) {
        suggestionsTask?.cancel()
        
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFocused else {
            searchSuggestions = []
            return
        }
        
        guard !normalizedQuery.isEmpty else {
            searchSuggestions = recentSearches
            return
        }
        
        searchSuggestions = SearchSuggestionComposer.recentMatches(query: normalizedQuery, recentSearches: recentSearches)
        
        suggestionsTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            
            let results = await GoogleSuggestService.suggestions(query: normalizedQuery)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.searchSuggestions = SearchSuggestionComposer.compose(
                    query: normalizedQuery,
                    recentSearches: self.recentSearches,
                    googleSuggestions: results
                )
            }
        }
    }
    
    func clearSearchSuggestions() {
        suggestionsTask?.cancel()
        searchSuggestions = []
    }
    
    func addRecentSearch(_ query: String) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        
        recentSearches.removeAll { $0.caseInsensitiveCompare(cleaned) == .orderedSame }
        recentSearches.insert(cleaned, at: 0)
        if recentSearches.count > 20 {
            recentSearches = Array(recentSearches.prefix(20))
        }
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
}
