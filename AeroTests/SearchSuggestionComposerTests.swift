import Testing
@testable import Aero

struct SearchSuggestionComposerTests {

    @Test func recentMatchesFiltersCaseInsensitive() {
        let recent = ["OpenAI", "apple store", "GitHub"]
        let matches = SearchSuggestionComposer.recentMatches(query: "app", recentSearches: recent)
        #expect(matches == ["apple store"])
    }

    @Test func composeDedupesRecentsAndRemote() {
        let recent = ["OpenAI", "apple store"]
        let remote = ["openai", "openai api", "Apple Store"]
        let result = SearchSuggestionComposer.compose(query: "o", recentSearches: recent, googleSuggestions: remote)
        #expect(result == ["OpenAI", "apple store", "openai api"])
    }

    @Test func emptyQueryReturnsRecentsOnly() {
        let recent = ["a", "b"]
        let result = SearchSuggestionComposer.recentMatches(query: "   ", recentSearches: recent)
        #expect(result == ["a", "b"])
    }
}

