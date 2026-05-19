import Foundation

extension BrowserViewModel {
    func fetchSearchSuggestions(for query: String) {
        suggestionsTask?.cancel()

        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty, isAddressBarFocused else {
            searchSuggestions = []
            return
        }

        // If the user is typing, keep the overlay alive with the last results while we debounce.
        suggestionsTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            let results = await GoogleSuggestService.suggestions(query: normalizedQuery)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.searchSuggestions = results
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
