import Foundation

extension BrowserViewModel {
    func fetchSearchSuggestions(for query: String) {
        suggestionsTask?.cancel()
        updateSuggestions(for: query)

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
        clearSuggestions()
    }

    func navigateToSearchSuggestion(_ suggestion: String) {
        addressBarText = suggestion
        submitAddressBar()
    }

    func fillAddressBar(with suggestion: String) {
        addressBarText = suggestion
    }

    func updateSuggestions(for query: String) {
        guard !query.isEmpty, isAddressBarFocused else {
            suggestions = []
            return
        }

        suggestions = suggestionProvider.suggestions(
            for: query,
            tabs: tabManager.tabs(in: activeBrowsingMode),
            favorites: favoritesStore.favorites,
            history: activeTab?.isPrivate == true ? [] : historyStore.items,
            activeTabID: activeTab?.id
        )
    }

    func clearSuggestions() {
        suggestions = []
    }

    func selectSuggestion(_ suggestion: BrowserSuggestion) {
        if let tabID = suggestion.tabID {
            tabManager.switchToTab(id: tabID)
        } else if let url = suggestion.url {
            addressBarText = url.absoluteString
            tabManager.loadInActiveTab(url: url)
        }

        isAddressBarFocused = false
        clearSearchSuggestions()
        chromeController.expand()
    }
}
