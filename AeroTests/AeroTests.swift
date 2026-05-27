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

    @Test func tabManagerStartsWithBlankTabWhenNoSessionExists() {
        let store = SpySessionStore(loadResult: nil)
        let manager = TabManager(sessionStore: store)

        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabIndex == 0)
        #expect(manager.activeTab?.url == nil)
        #expect(store.savedSessions.last?.tabs.count == 1)
    }

    @Test func tabManagerRestoresSavedTabsInOrder() {
        let firstURL = URL(string: "https://example.com")!
        let secondURL = URL(string: "https://swift.org")!
        let session = BrowserSessionState(
            activeTabIndex: 1,
            tabs: [
                RestoredTabState(url: firstURL, title: "Example", createdAt: Date(), lastAccessedAt: Date()),
                RestoredTabState(url: secondURL, title: "Swift", createdAt: Date(), lastAccessedAt: Date()),
            ]
        )

        let manager = TabManager(sessionStore: SpySessionStore(loadResult: session))

        #expect(manager.tabs.map { $0.url } == [firstURL, secondURL])
        #expect(manager.tabs.map(\.title) == ["Example", "Swift"])
        #expect(manager.activeTabIndex == 1)
    }

    @Test func tabManagerClampsInvalidRestoredActiveIndex() {
        let session = BrowserSessionState(
            activeTabIndex: 99,
            tabs: [
                RestoredTabState(url: URL(string: "https://example.com")!, title: "Example", createdAt: Date(), lastAccessedAt: Date()),
            ]
        )

        let manager = TabManager(sessionStore: SpySessionStore(loadResult: session))

        #expect(manager.activeTabIndex == 0)
    }

    @Test func tabManagerFallsBackWhenRestoredSessionIsEmpty() {
        let store = SpySessionStore(loadResult: BrowserSessionState(activeTabIndex: 4, tabs: []))
        let manager = TabManager(sessionStore: store)

        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabIndex == 0)
        #expect(manager.activeTab?.url == nil)
    }

    @Test func tabManagerCapsRestoredTabsAtMaximum() {
        let restoredTabs = (0..<(TabManager.maxTabs + 5)).map { index in
            RestoredTabState(
                url: URL(string: "https://example\(index).com")!,
                title: "Example \(index)",
                createdAt: Date(),
                lastAccessedAt: Date()
            )
        }
        let session = BrowserSessionState(activeTabIndex: TabManager.maxTabs + 4, tabs: restoredTabs)

        let manager = TabManager(sessionStore: SpySessionStore(loadResult: session))

        #expect(manager.tabs.count == TabManager.maxTabs)
        #expect(manager.activeTabIndex == TabManager.maxTabs - 1)
    }

    @Test func sessionStoreReturnsNilForCorruptSessionFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aero_corrupt_session_\(UUID().uuidString).json")
        try Data("not-json".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let store = SessionStore(fileURL: fileURL)

        #expect(store.loadSession() == nil)
    }

    @Test func tabManagerFallsBackWhenSessionFileIsCorrupt() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aero_corrupt_manager_session_\(UUID().uuidString).json")
        try Data("not-json".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = TabManager(sessionStore: SessionStore(fileURL: fileURL))

        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabIndex == 0)
        #expect(manager.activeTab?.url == nil)
    }

    @Test func sessionStoreSavesAndLoadsSession() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aero_session_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let state = BrowserSessionState(
            activeTabIndex: 0,
            tabs: [
                RestoredTabState(
                    url: URL(string: "https://example.com")!,
                    title: "Example",
                    createdAt: date,
                    lastAccessedAt: date
                ),
            ]
        )
        let store = SessionStore(fileURL: fileURL)

        store.saveSession(state)

        #expect(store.loadSession() == state)
    }

    @Test func tabManagerSavesAfterCreateCloseSwitchAndLoad() {
        let store = SpySessionStore(loadResult: nil)
        let manager = TabManager(sessionStore: store)
        let initialSaveCount = store.savedSessions.count

        let firstURL = URL(string: "https://example.com")!
        let secondURL = URL(string: "https://swift.org")!
        let firstTab = manager.loadInActiveTabAndReturnActiveTab(url: firstURL)
        let secondTab = manager.newTab(url: secondURL)
        manager.switchToTab(id: firstTab.id)
        manager.closeTab(id: secondTab.id)

        #expect(store.savedSessions.count >= initialSaveCount + 4)
        #expect(store.savedSessions.last?.tabs.count == 1)
        #expect(store.savedSessions.last?.tabs.first?.url == firstURL)
        #expect(store.savedSessions.last?.activeTabIndex == 0)
    }

    @Test func tabManagerReopensLastClosedTabAsActiveTab() {
        let store = SpySessionStore(loadResult: nil)
        let manager = TabManager(sessionStore: store)

        let firstURL = URL(string: "https://example.com")!
        let closedURL = URL(string: "https://swift.org")!
        let firstTab = manager.loadInActiveTabAndReturnActiveTab(url: firstURL)
        firstTab.title = "Example"
        let closedTab = manager.newTab(url: closedURL)
        closedTab.title = "Swift"
        let closedCreatedAt = closedTab.createdAt
        let closedLastAccessedAt = closedTab.lastAccessedAt

        manager.closeTab(id: closedTab.id)

        #expect(manager.tabs.map { $0.url } == [firstURL])
        #expect(manager.recentlyClosedTabCount == 1)
        #expect(manager.canReopenLastClosedTab)

        let reopenedTab = manager.reopenLastClosedTab()

        #expect(reopenedTab?.url == closedURL)
        #expect(reopenedTab?.title == "Swift")
        #expect(reopenedTab?.createdAt == closedCreatedAt)
        #expect(reopenedTab?.lastAccessedAt == closedLastAccessedAt)
        #expect(manager.activeTab?.id == reopenedTab?.id)
        #expect(manager.tabs.map { $0.url } == [firstURL, closedURL])
        #expect(manager.recentlyClosedTabCount == 0)
        #expect(store.savedSessions.last?.tabs.map { $0.url } == [firstURL, closedURL])
        #expect(store.savedSessions.last?.activeTabIndex == 1)
    }

    @Test func tabManagerReopensTabsInLastClosedOrder() {
        let manager = TabManager(sessionStore: SpySessionStore(loadResult: nil))

        let firstURL = URL(string: "https://example.com")!
        let secondURL = URL(string: "https://swift.org")!
        let thirdURL = URL(string: "https://developer.apple.com")!
        let firstTab = manager.loadInActiveTabAndReturnActiveTab(url: firstURL)
        let secondTab = manager.newTab(url: secondURL)
        let thirdTab = manager.newTab(url: thirdURL)

        manager.closeTab(id: secondTab.id)
        manager.closeTab(id: thirdTab.id)

        let firstReopenedTab = manager.reopenLastClosedTab()
        let secondReopenedTab = manager.reopenLastClosedTab()

        #expect(manager.tabs.first?.id == firstTab.id)
        #expect(firstReopenedTab?.url == thirdURL)
        #expect(secondReopenedTab?.url == secondURL)
        #expect(manager.reopenLastClosedTab() == nil)
    }

    @Test func tabManagerCapsRecentlyClosedTabsAtMaximum() {
        let manager = TabManager(sessionStore: SpySessionStore(loadResult: nil))
        let closedTabCount = TabManager.maxRecentlyClosedTabs + 3

        for index in 0..<closedTabCount {
            let url = URL(string: "https://example.com/\(index)")!
            let tab = manager.loadInActiveTabAndReturnActiveTab(url: url)
            manager.closeTab(id: tab.id)
        }

        #expect(manager.recentlyClosedTabCount == TabManager.maxRecentlyClosedTabs)

        var reopenedURLs: [String] = []
        for _ in 0..<TabManager.maxRecentlyClosedTabs {
            if let urlString = manager.reopenLastClosedTab()?.url?.absoluteString {
                reopenedURLs.append(urlString)
            }
        }

        let expectedURLs = (3..<closedTabCount)
            .reversed()
            .map { "https://example.com/\($0)" }
        #expect(reopenedURLs == expectedURLs)
        #expect(!manager.canReopenLastClosedTab)
    }

}

private final class SpySessionStore: SessionStoring {
    let loadResult: BrowserSessionState?
    var savedSessions: [BrowserSessionState] = []

    init(loadResult: BrowserSessionState?) {
        self.loadResult = loadResult
    }

    func loadSession() -> BrowserSessionState? {
        loadResult
    }

    func saveSession(_ session: BrowserSessionState) {
        savedSessions.append(session)
    }
}

private extension TabManager {
    func loadInActiveTabAndReturnActiveTab(url: URL) -> Tab {
        loadInActiveTab(url: url)
        return activeTab!
    }
}
