import Foundation

extension BrowserViewModel {
    func fetchWikiSuggestions(for query: String) {
        wikiTask?.cancel()
        guard !query.isEmpty, isAddressBarFocused else {
            wikiSuggestions = []
            return
        }

        wikiTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            let results = await WikipediaService.search(query: query)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.wikiSuggestions = results
            }
        }
    }

    func clearWikiSuggestions() {
        wikiTask?.cancel()
        wikiSuggestions = []
    }

    func navigateToWikiSuggestion(_ suggestion: WikiSuggestion) {
        guard let url = suggestion.pageURL else { return }
        addressBarText = url.absoluteString
        tabManager.loadInActiveTab(url: url)
        isAddressBarFocused = false
        clearWikiSuggestions()
        chromeController.expand()
    }
}
