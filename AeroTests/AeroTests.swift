import Foundation
import Testing
@testable import Aero

struct AeroTests {

    @Test func chromeStaysExpandedAtTop() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 0, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 8, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeDoesNotCollapseWhenPageCannotScroll() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 80, contentHeight: 780, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 140, contentHeight: 780, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeDoesNotCollapseBeforeDownwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 120, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeCollapsesAfterDownwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .compact)
    }

    @Test func chromeExpandsAfterUpwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 88, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func forceExpandResetsChromeMode() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))
        controller.expand()

        #expect(controller.mode == .expanded)
    }

    @Test func localSuggestionsRankOpenTabsAboveFavoritesAndHistory() {
        let provider = LocalSuggestionProvider()
        let tab = Tab(url: URL(string: "https://example.com")!)
        tab.title = "Example"
        let favorite = FavoriteItem(title: "Example", url: URL(string: "https://example.com")!)
        let history = HistoryItem(url: URL(string: "https://example.com")!, title: "Example")

        let suggestions = provider.suggestions(
            for: "example",
            tabs: [tab],
            favorites: [favorite],
            history: [history],
            activeTabID: nil
        )

        #expect(suggestions.count == 1)
        #expect(suggestions.first?.kind == .tab)
    }

    @Test func localSuggestionsRankFavoritesAboveHistory() {
        let provider = LocalSuggestionProvider()
        let favorite = FavoriteItem(title: "Swift", url: URL(string: "https://swift.org")!)
        let history = HistoryItem(url: URL(string: "https://swift.org")!, title: "Swift")

        let suggestions = provider.suggestions(
            for: "swift",
            tabs: [],
            favorites: [favorite],
            history: [history],
            activeTabID: nil
        )

        #expect(suggestions.count == 1)
        #expect(suggestions.first?.kind == .favorite)
    }

    @Test func localSuggestionsGroupHistoryDuplicatesAndUseLatestTitle() {
        let provider = LocalSuggestionProvider()
        let older = Date().addingTimeInterval(-86_400)
        let newer = Date()
        let url = URL(string: "https://developer.apple.com/documentation")!
        let oldVisit = HistoryItem(url: url, title: "Old Apple Docs", visitDate: older)
        let newVisit = HistoryItem(url: url, title: "Apple Documentation", visitDate: newer)

        let suggestions = provider.suggestions(
            for: "apple",
            tabs: [],
            favorites: [],
            history: [oldVisit, newVisit],
            activeTabID: nil
        )

        #expect(suggestions.count == 1)
        #expect(suggestions.first?.kind == .history)
        #expect(suggestions.first?.title == "Apple Documentation")
    }

    @Test func localSuggestionsExcludeNonMatches() {
        let provider = LocalSuggestionProvider()
        let favorite = FavoriteItem(title: "GitHub", url: URL(string: "https://github.com")!)
        let history = HistoryItem(url: URL(string: "https://swift.org")!, title: "Swift")

        let suggestions = provider.suggestions(
            for: "news",
            tabs: [],
            favorites: [favorite],
            history: [history],
            activeTabID: nil
        )

        #expect(suggestions.isEmpty)
    }

    @Test func localSuggestionsCapResultsAtFive() {
        let provider = LocalSuggestionProvider()
        let favorites = (0..<8).map { index in
            FavoriteItem(title: "Example \(index)", url: URL(string: "https://example\(index).com")!)
        }

        let suggestions = provider.suggestions(
            for: "example",
            tabs: [],
            favorites: favorites,
            history: [],
            activeTabID: nil
        )

        #expect(suggestions.count == 5)
    }

    @Test func localSuggestionsMatchCaseInsensitivelyAcrossTitleHostAndURL() {
        let provider = LocalSuggestionProvider()
        let titleFavorite = FavoriteItem(title: "Apple Developer", url: URL(string: "https://developer.apple.com")!)
        let hostFavorite = FavoriteItem(title: "Search", url: URL(string: "https://github.com/search")!)
        let urlFavorite = FavoriteItem(title: "Release Notes", url: URL(string: "https://swift.org/blog/releases")!)

        let titleMatches = provider.suggestions(
            for: "apple",
            tabs: [],
            favorites: [titleFavorite],
            history: [],
            activeTabID: nil
        )
        let hostMatches = provider.suggestions(
            for: "GITHUB",
            tabs: [],
            favorites: [hostFavorite],
            history: [],
            activeTabID: nil
        )
        let urlMatches = provider.suggestions(
            for: "blog/releases",
            tabs: [],
            favorites: [urlFavorite],
            history: [],
            activeTabID: nil
        )

        #expect(titleMatches.first?.title == "Apple Developer")
        #expect(hostMatches.first?.title == "Search")
        #expect(urlMatches.first?.title == "Release Notes")
    }

}
