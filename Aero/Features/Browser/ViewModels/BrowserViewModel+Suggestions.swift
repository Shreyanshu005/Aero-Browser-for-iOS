import Foundation

extension BrowserViewModel {
    func fetchSearchSuggestions(for query: String) {
        suggestionsTask?.cancel()

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAddressBarFocused else {
            searchSuggestions = []
            return
        }

        // Empty query: show recents.
        guard !normalizedQuery.isEmpty else {
            searchSuggestions = recentSearches
            return
        }

        let recentMatches = SearchSuggestionComposer.recentMatches(query: normalizedQuery, recentSearches: recentSearches)
        searchSuggestions = recentMatches

        // If the user is typing, keep the overlay alive with the last results while we debounce.
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

    func navigateToSearchSuggestion(_ suggestion: String) {
        addressBarText = suggestion
        submitAddressBar()
    }

    func fillAddressBar(with suggestion: String) {
        addressBarText = suggestion
    }
}
