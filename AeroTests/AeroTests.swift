import Foundation
import Testing
import WebKit
@testable import Aero

struct AeroTests {

    @Test func externalURLPolicyAllowsWebViewSchemes() {
        let policy = ExternalURLPolicy()

        #expect(policy.decision(for: URL(string: "https://example.com")!) == .allowInWebView)
        #expect(policy.decision(for: URL(string: "http://example.com")!) == .allowInWebView)
        #expect(policy.decision(for: URL(string: "about:blank")!) == .allowInWebView)
        #expect(policy.decision(for: URL(string: "aero://new-tab")!) == .allowInWebView)
    }

    @Test func externalURLPolicyRoutesExternalSchemesOutOfWebView() {
        let policy = ExternalURLPolicy()
        let mail = URL(string: "mailto:hello@example.com")!
        let phone = URL(string: "tel:+15551234567")!
        let message = URL(string: "sms:+15551234567")!
        let appStore = URL(string: "itms-apps://itunes.apple.com/app/id123456789")!
        let deepLink = URL(string: "sampleapp://open/item")!

        #expect(policy.decision(for: mail) == .openExternally(mail))
        #expect(policy.decision(for: phone) == .openExternally(phone))
        #expect(policy.decision(for: message) == .openExternally(message))
        #expect(policy.decision(for: appStore) == .openExternally(appStore))
        #expect(policy.decision(for: deepLink) == .openExternally(deepLink))
    }

    @Test func externalURLPolicyCancelsUnsupportedSchemes() {
        let policy = ExternalURLPolicy()

        #expect(policy.decision(for: nil) == .cancel)
        #expect(policy.decision(for: URL(string: "example.com")) == .cancel)
        #expect(policy.decision(for: URL(string: "javascript:alert(1)")!) == .cancel)
        #expect(policy.decision(for: URL(string: "data:text/html,Hello")!) == .cancel)
        #expect(policy.decision(for: URL(string: "blob:https://example.com/id")!) == .cancel)
        #expect(policy.decision(for: URL(fileURLWithPath: "/tmp/example")) == .cancel)
    }

    @Test func javaScriptAlertCompletionRunsOnceWhenAccepted() {
        var completionCount = 0
        let request = JavaScriptDialogRequest(
            kind: .alert,
            message: "Hello",
            sourceHost: "example.com",
            completion: .alert {
                completionCount += 1
            }
        )

        request.accept()
        request.accept()
        request.cancel()

        #expect(completionCount == 1)
    }

    @Test func javaScriptConfirmCancelReturnsFalseOnce() {
        var results: [Bool] = []
        let request = JavaScriptDialogRequest(
            kind: .confirm,
            message: "Continue?",
            sourceHost: "example.com",
            completion: .confirm {
                results.append($0)
            }
        )

        request.cancel()
        request.accept()

        #expect(results == [false])
    }

    @Test func javaScriptPromptAcceptReturnsEnteredTextOnce() {
        var results: [String?] = []
        let request = JavaScriptDialogRequest(
            kind: .prompt(defaultText: "Default"),
            message: "Name",
            sourceHost: "example.com",
            completion: .prompt {
                results.append($0)
            }
        )

        request.accept(promptText: "Ada")
        request.cancel()

        #expect(results.count == 1)
        #expect(results[0] == "Ada")
    }

    @Test func javaScriptPromptAcceptUsesDefaultTextWhenNoTextProvided() {
        var result: String?
        let request = JavaScriptDialogRequest(
            kind: .prompt(defaultText: "Default"),
            message: "Name",
            sourceHost: "example.com",
            completion: .prompt {
                result = $0
            }
        )

        request.accept()

        #expect(result == "Default")
    }

    @Test func siteStatusBuildsDefaultPermissionsForURL() {
        let status = SiteStatus(
            url: URL(string: "https://www.example.com/path")!,
            isSecureConnection: true,
            contentBlockerEnabled: true
        )

        #expect(status.host == "example.com")
        #expect(status.displayHost == "example.com")
        #expect(status.isSecureConnection)
        #expect(status.contentBlocker == .enabled)
        #expect(status.permission(for: .camera)?.disposition == .ask)
        #expect(status.permission(for: .microphone)?.disposition == .ask)
        #expect(status.permission(for: .location)?.disposition == .unsupported)
        #expect(status.permission(for: .popups)?.disposition == .default)
    }

    @Test func siteStatusRecordsObservedMediaAndPopupRequests() {
        var status = SiteStatus(url: URL(string: "https://example.com")!, isSecureConnection: true)

        status.recordMediaCaptureRequest(.cameraAndMicrophone)
        status.recordPopupAttempt()

        #expect(status.permission(for: .camera)?.wasObservedThisSession == true)
        #expect(status.permission(for: .microphone)?.wasObservedThisSession == true)
        #expect(status.permission(for: .popups)?.wasObservedThisSession == true)
        #expect(status.permission(for: .camera)?.disposition == .ask)
        #expect(status.permission(for: .popups)?.disposition == .default)
    }

    @Test func siteStatusResetsObservedPermissionsWhenHostChanges() {
        var status = SiteStatus(url: URL(string: "https://example.com")!, isSecureConnection: true)
        status.recordMediaCaptureRequest(.camera)
        status.recordPopupAttempt()

        status.updatePage(url: URL(string: "https://swift.org/documentation")!, isSecureConnection: true)

        #expect(status.host == "swift.org")
        #expect(status.permission(for: .camera)?.wasObservedThisSession == false)
        #expect(status.permission(for: .popups)?.wasObservedThisSession == false)
    }

    @Test func siteStatusPreservesObservedPermissionsOnSameHost() {
        var status = SiteStatus(url: URL(string: "https://example.com/start")!, isSecureConnection: true)
        status.recordMediaCaptureRequest(.microphone)

        status.updatePage(url: URL(string: "https://example.com/next")!, isSecureConnection: true)

        #expect(status.host == "example.com")
        #expect(status.permission(for: .microphone)?.wasObservedThisSession == true)
    }

    @Test func siteStatusUpdatesContentBlockerState() {
        var status = SiteStatus(url: URL(string: "https://example.com")!, isSecureConnection: true)

        status.updateContentBlocker(isEnabled: false)

        #expect(status.contentBlocker == .disabled)
    }

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

    @Test func browserErrorUsesFailingURLAndFriendlyOfflineMessage() {
        let requestedURL = URL(string: "https://requested.example")!
        let failingURL = URL(string: "https://offline.example/path")!
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSURLErrorFailingURLErrorKey: failingURL]
        )

        let browserError = BrowserError(error: error, url: requestedURL)

        #expect(browserError.kind == .offline)
        #expect(browserError.url == failingURL)
        #expect(browserError.title == "You're offline")
        #expect(browserError.message == "Check your internet connection, then try again.")
        #expect(browserError.displayHost == "offline.example")
    }

    @Test func browserErrorDoesNotDisplayCancelledNavigation() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)

        #expect(BrowserError.shouldDisplay(error: error) == false)
    }

    @Test func navigationFailureSetsAndClearsTabError() {
        let viewModel = BrowserViewModel()
        viewModel.tabManager = TabManager(sessionStore: SpySessionStore(loadResult: nil))
        let url = URL(string: "https://missing.example")!
        viewModel.tabManager.loadInActiveTab(url: url)

        viewModel.handleNavigationEvent(
            .didFailLoading(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost))
        )

        #expect(viewModel.activeTab?.navigationError?.kind == .cannotFindServer)
        #expect(viewModel.activeTab?.navigationError?.url == url)

        viewModel.handleNavigationEvent(.didStartLoading)

        #expect(viewModel.activeTab?.navigationError == nil)
    }

    @Test func tabManagerClearsNavigationErrorWhenLoadingURL() {
        let manager = TabManager(sessionStore: SpySessionStore(loadResult: nil))
        let firstURL = URL(string: "https://offline.example")!
        let nextURL = URL(string: "https://example.com")!
        let tab = manager.loadInActiveTabAndReturnActiveTab(url: firstURL)
        tab.navigationError = BrowserError(
            error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet),
            url: firstURL
        )

        manager.loadInActiveTab(url: nextURL)

        #expect(tab.navigationError == nil)
        #expect(tab.url == nextURL)
    }

    @Test func securitySummaryShowsHTTPSDetailsWithoutClaimingCertificateWhenUnavailable() {
        let summary = SecuritySummary(url: URL(string: "https://www.example.com/account")!)

        #expect(summary.host == "example.com")
        #expect(summary.scheme == "HTTPS")
        #expect(summary.isSecure)
        #expect(summary.httpsStatus == "Enabled")
        #expect(summary.certificateStatus == "Not available")
    }

    @Test func securitySummaryFlagsHTTPAsNotSecure() {
        let summary = SecuritySummary(url: URL(string: "http://example.com")!)

        #expect(summary.status == .insecureHTTP)
        #expect(!summary.isSecure)
        #expect(summary.httpsStatus == "Not enabled")
        #expect(summary.explanation.contains("not encrypted"))
    }

    @Test func securitySummaryIncludesMatchingCertificateDetails() {
        let certificate = CertificateSummary(
            host: "example.com",
            subject: "example.com",
            certificateCount: 2,
            fingerprintSHA256: "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"
        )

        let summary = SecuritySummary(
            url: URL(string: "https://example.com")!,
            certificateSummary: certificate
        )

        #expect(summary.certificateSummary == certificate)
        #expect(summary.certificateStatus == "example.com")
        #expect(summary.detailRows.contains { $0.id == "fingerprint" })
    }

    @Test func securitySummaryIgnoresMismatchedCertificateDetails() {
        let certificate = CertificateSummary(
            host: "cdn.example.com",
            subject: "cdn.example.com",
            certificateCount: 1,
            fingerprintSHA256: nil
        )

        let summary = SecuritySummary(
            url: URL(string: "https://example.com")!,
            certificateSummary: certificate
        )

        #expect(summary.certificateSummary == nil)
        #expect(summary.certificateStatus == "Not available")
    }

    @Test func securitySummaryTreatsBrowserPagesAsLocal() {
        let summary = SecuritySummary(url: URL(string: "aero://new-tab")!)

        #expect(summary.status == .browserPage)
        #expect(!summary.isSecure)
        #expect(summary.httpsStatus == "Not applicable")
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

    @Test func tabManagerDiscardsWebViewsForReconfigurationWithoutChangingRestorableState() {
        let manager = TabManager(sessionStore: SpySessionStore(loadResult: nil))
        let url = URL(string: "https://example.com")!
        let tab = manager.loadInActiveTabAndReturnActiveTab(url: url)
        tab.title = "Example"
        tab.isLoading = true
        tab.estimatedProgress = 0.5
        tab.canGoBack = true
        tab.canGoForward = true

        manager.discardWebViewsForReconfiguration()

        #expect(manager.activeTab?.id == tab.id)
        #expect(manager.activeTab?.url == url)
        #expect(manager.activeTab?.title == "Example")
        #expect(manager.activeTab?.isLoading == false)
        #expect(manager.activeTab?.estimatedProgress == 0.0)
        #expect(manager.activeTab?.canGoBack == false)
        #expect(manager.activeTab?.canGoForward == false)
    }

    @Test func tabManagerCreatesPrivateTabsWithoutSavingThemToSession() {
        let store = SpySessionStore(loadResult: nil)
        let manager = TabManager(sessionStore: store)
        let initialSaveCount = store.savedSessions.count
        let privateURL = URL(string: "https://private.example")!

        let privateTab = manager.newPrivateTab(url: privateURL)

        #expect(privateTab.isPrivate)
        #expect(manager.activeBrowsingMode == .privateBrowsing)
        #expect(manager.tabs(in: .privateBrowsing).map(\.url) == [privateURL])
        #expect(store.savedSessions.count == initialSaveCount)

        manager.saveSession()

        #expect(store.savedSessions.last?.tabs.count == 1)
        #expect(store.savedSessions.last?.tabs.contains { $0.url == privateURL } == false)
    }

    @Test func tabManagerSwitchesBetweenSeparatedBrowsingModes() {
        let manager = TabManager(sessionStore: SpySessionStore(loadResult: nil))
        let standardTab = manager.activeTab!
        let privateTab = manager.newPrivateTab()

        #expect(manager.activeTab?.id == privateTab.id)
        #expect(manager.tabCount == 1)

        manager.switchBrowsingMode(.standard)

        #expect(manager.activeTab?.id == standardTab.id)
        #expect(manager.tabCount == 1)
        #expect(manager.tabs(in: .standard).map(\.id) == [standardTab.id])
        #expect(manager.tabs(in: .privateBrowsing).map(\.id) == [privateTab.id])
    }

    @MainActor
    @Test func privateTabsUseNonPersistentWebsiteDataStore() {
        let privateWebView = Tab(browsingMode: .privateBrowsing).createWebView()
        let standardWebView = Tab().createWebView()

        #expect(privateWebView.configuration.websiteDataStore.isPersistent == false)
        #expect(standardWebView.configuration.websiteDataStore.isPersistent)
    }

    @Test func privateNavigationDoesNotWriteHistoryOrSession() {
        let sessionStore = SpySessionStore(loadResult: nil)
        let manager = TabManager(sessionStore: sessionStore)
        let initialSaveCount = sessionStore.savedSessions.count
        let privateURL = URL(string: "https://private.example/page")!
        let privateTab = manager.newPrivateTab(url: privateURL)
        privateTab.title = "Private Page"

        let historyURL = temporaryFileURL(prefix: "aero_private_history", fileExtension: "json")
        let favoritesURL = temporaryFileURL(prefix: "aero_private_favorites", fileExtension: "json")
        let downloadsURL = temporaryFileURL(prefix: "aero_private_downloads", fileExtension: "json")
        let downloadsDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aero_private_downloads_\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: historyURL)
            try? FileManager.default.removeItem(at: favoritesURL)
            try? FileManager.default.removeItem(at: downloadsURL)
            try? FileManager.default.removeItem(at: downloadsDirectoryURL)
        }

        let viewModel = BrowserViewModel(
            tabManager: manager,
            historyStore: HistoryStore(fileURL: historyURL),
            favoritesStore: FavoritesStore(fileURL: favoritesURL),
            downloadManager: DownloadManager(
                store: DownloadStore(fileURL: downloadsURL),
                downloadsDirectoryURL: downloadsDirectoryURL
            ),
            compileContentBlocker: false
        )

        viewModel.handleNavigationEvent(.didFinishLoading)
        viewModel.handleNavigationEvent(.didUpdateTitle("Private Page"))
        viewModel.handleNavigationEvent(.didUpdateURL(privateURL))

        #expect(viewModel.historyStore.items.isEmpty)
        #expect(sessionStore.savedSessions.count == initialSaveCount)
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

private func temporaryFileURL(prefix: String, fileExtension pathExtension: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)_\(UUID().uuidString).\(pathExtension)")
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
