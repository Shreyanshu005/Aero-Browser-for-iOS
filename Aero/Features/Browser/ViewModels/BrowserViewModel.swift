import SwiftUI
import WebKit
import Observation

@Observable
@MainActor
final class BrowserViewModel {


    private(set) var searchService = SearchService()
    var searchSuggestions: [String] { searchService.searchSuggestions }
    var recentSearches: [String] { searchService.recentSearches }
    @ObservationIgnored
    var suggestionsTask: Task<Void, Never>?
    var suggestions: [BrowserSuggestion] = []

    @ObservationIgnored
    let suggestionProvider = LocalSuggestionProvider()

    @ObservationIgnored
    private var queuedJavaScriptDialogs: [JavaScriptDialogRequest] = []
    var tabManager: TabManager
    var historyStore: HistoryStore
    var favoritesStore: FavoritesStore
    var downloadManager: DownloadManager
    @ObservationIgnored
    let contentBlocker: ContentBlocker


    @ObservationIgnored
    private let settingsStore: BrowserSettingsStoring
    @ObservationIgnored
    var agentRunEngineStorage: AgentRunEngine?
    @ObservationIgnored
    var agentBrowserToolsStorage: LiveAgentBrowserTools?

    var offlineService = OfflineReadingService()
    var pageProfiler = PagePerformanceProfiler()
    var biometricAuth = BiometricAuthService()

    private(set) var navigationService: NavigationService!

    var isShowingTabGrid: Bool = false
    var isAddressBarFocused: Bool = false
    var addressBarText: String = ""
    var searchEngine: SearchEngine {
        didSet {
            guard searchEngine != oldValue else { return }
            saveSettings()
        }
    }
    var contentBlockerEnabled: Bool {
        didSet {
            guard contentBlockerEnabled != oldValue else { return }
            saveSettings()
            refreshSiteStatuses()
            recreateWebViewsForContentBlockerConfigurationChange()
        }
    }
    private(set) var webViewConfigurationRevision: Int = 0
    var chromeController = BrowserChromeController()

    var sheetRouter = SheetRouter()


    var showMenu: Bool {
        get { sheetRouter.activeSheet == .menu }
        set { if newValue { sheetRouter.present(.menu) } else { sheetRouter.dismissSheet() } }
    }
    var showHistory: Bool {
        get { sheetRouter.activeSheet == .history }
        set { if newValue { sheetRouter.present(.history) } else { sheetRouter.dismissSheet() } }
    }
    var showBookmarks: Bool {
        get { sheetRouter.activeSheet == .bookmarks }
        set { if newValue { sheetRouter.present(.bookmarks) } else { sheetRouter.dismissSheet() } }
    }
    var showDownloads: Bool {
        get { sheetRouter.activeSheet == .downloads }
        set { if newValue { sheetRouter.present(.downloads) } else { sheetRouter.dismissSheet() } }
    }
    var showSettings: Bool {
        get { sheetRouter.activeSheet == .settings }
        set { if newValue { sheetRouter.present(.settings) } else { sheetRouter.dismissSheet() } }
    }
    var showAddBookmark: Bool {
        get { sheetRouter.activeSheet == .addBookmark }
        set { if newValue { sheetRouter.present(.addBookmark) } else { sheetRouter.dismissSheet() } }
    }
    var showTrackerReceipt: Bool {
        get { sheetRouter.activeSheet == .trackerReceipt }
        set { if newValue { sheetRouter.present(.trackerReceipt) } else { sheetRouter.dismissSheet() } }
    }
    

    var showAgentPanel: Bool = false
    var pendingDownload: PendingDownload?
    var pendingJavaScriptDialog: JavaScriptDialogRequest?
    var pendingLinkActionRequest: LinkActionRequest?

    var showReaderMode: Bool {
        get { sheetRouter.activeFullScreenCover == .readerMode }
        set { if newValue { sheetRouter.presentFullScreen(.readerMode) } else { sheetRouter.dismissFullScreenCover() } }
    }
    var showFindInPage: Bool {
        get { sheetRouter.activeFullScreenCover == .findInPage }
        set { if newValue { sheetRouter.presentFullScreen(.findInPage) } else { sheetRouter.dismissFullScreenCover() } }
    }

    var activeTab: Tab? { tabManager.activeTab }
    var activeBrowsingMode: BrowsingMode { tabManager.activeBrowsingMode }
    var chromeMode: BottomChromeMode { chromeController.mode }

    var isTabSwipeActive: Bool = false
    var tabSwipeTranslationX: CGFloat = 0
    var tabSwipeTargetTabID: UUID? = nil
    var tabSwipeDirection: CGFloat = 0

    init(
        tabManager: TabManager? = nil,
        historyStore: HistoryStore? = nil,
        favoritesStore: FavoritesStore? = nil,
        downloadManager: DownloadManager = DownloadManager(),
        contentBlocker: ContentBlocker = ContentBlocker(),
        settingsStore: BrowserSettingsStoring = BrowserSettingsStore(),
        compileContentBlocker: Bool = true
    ) {
        self.settingsStore = settingsStore
        let settings = settingsStore.loadSettings()
        self.searchEngine = settings.searchEngine
        self.contentBlockerEnabled = settings.contentBlockerEnabled
        self.tabManager = tabManager ?? TabManager()
        self.historyStore = historyStore ?? HistoryStore()
        self.favoritesStore = favoritesStore ?? FavoritesStore()
        self.downloadManager = downloadManager
        self.contentBlocker = contentBlocker


        refreshSiteStatuses()
        self.pageProfiler.isEnabled = true
        self.navigationService = NavigationService(tabManager: self.tabManager, chromeController: self.chromeController)

        if compileContentBlocker {
            compileContentBlockerRules()
        }
    }

    private func saveSettings() {
        settingsStore.saveSettings(
            BrowserSettings(
                searchEngine: searchEngine,
                contentBlockerEnabled: contentBlockerEnabled
            )
        )
    }



    func submitAddressBar() {
        let input = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let classification = URLInput.classify(input)
        let url: URL

        switch classification {
        case .url(let directURL):
            url = directURL
        case .search(let query):
            addRecentSearch(query)
            guard let searchURL = searchEngine.searchURL(for: query) else { return }
            url = searchURL
        }

        if let duplicate = TabDeduplicationService.findDuplicate(url: url, in: tabManager.tabs, excluding: activeTab?.id) {
            let previousTabId = activeTab?.id
            let previousTabUrl = activeTab?.url
            
            tabManager.switchToTab(id: duplicate.id)
            
            if previousTabUrl == nil, let id = previousTabId {
                tabManager.closeTab(id: id)
            }
        } else {
            tabManager.loadInActiveTab(url: url)
        }

        isAddressBarFocused = false

        searchService.clearSearchSuggestions()
        clearSuggestions()
        chromeController.expand()
    }

    private func addRecentSearch(_ query: String) {
        searchService.addRecentSearch(query)
    }

    func navigateToSearchSuggestion(_ suggestion: String) {
        addressBarText = suggestion
        submitAddressBar()
    }

    func fillAddressBar(with text: String) {
        addressBarText = text
    }

    func syncAddressBarWithActiveTab() {
        if !isAddressBarFocused {
            if let url = activeTab?.url {
                addressBarText = url.absoluteString
            } else {
                addressBarText = ""
            }
        }
    }

    func handleNavigationEvent(_ event: NavigationEvent) {
        switch event {
        case .didStartLoading:
            activeTab?.navigationError = nil
        case .didFinishLoading:
            activeTab?.navigationError = nil
            if let tab = activeTab, !tab.isPrivate, let url = tab.url, !url.isInternalPage {
                historyStore.addVisit(url: url, title: tab.title)
            }
            saveSessionForActiveStandardTab()
        case .didFailLoading(let error):
            let browserError = BrowserError(error: error, url: activeTab?.displayURL)
            guard browserError.shouldDisplay else { return }
            activeTab?.navigationError = browserError
            chromeController.expand()
        case .didUpdateTitle(_), .didUpdateURL(_):
            saveSessionForActiveStandardTab()
        case .didRequestDownload(let pendingDownload):
            requestDownload(pendingDownload)
        case .didRequestJavaScriptDialog(let request):
            requestJavaScriptDialog(request)
        case .didRequestLinkActions(let request):
            requestLinkActions(request)
        case .didScroll(let metrics):
            guard activeTab?.url != nil,
                  isAddressBarFocused == false,
                  showFindInPage == false,
                  isShowingTabGrid == false else {
                chromeController.expand()
                return
            }

            chromeController.handleScroll(metrics)
        default:
            break
        }
    }


    func reopenLastClosedTab() {
        tabManager.reopenLastClosedTab()
    }
    
    func closeTab(_ tab: Tab) {
        tabManager.closeTab(id: tab.id)
    }

    func closeAllTabs() {
        tabManager.closeAllTabs()
    }

    func switchBrowsingMode(_ mode: BrowsingMode) {
        tabManager.switchBrowsingMode(mode)
    }
    
    @discardableResult
    func newPrivateTab() -> Tab {
        let tab = tabManager.newPrivateTab()
        chromeController.expand()
        return tab
    }
    
    @discardableResult
    func newTab() -> Tab {
        let tab = tabManager.newTab()
        chromeController.expand()
        return tab
    }
    
    var canReopenLastClosedTab: Bool {
        tabManager.recentlyClosedTabCount > 0
    }

    private func saveSessionForActiveStandardTab() {
        guard activeTab?.browsingMode.isSessionRestorable == true else { return }
        tabManager.saveSession()
    }

    func goBack() {
        navigationService.goBack()
    }

    func goForward() {
        navigationService.goForward()
    }

    func reload() {
        if activeTab?.navigationError != nil {
            retryFailedNavigation()
            return
        }

        activeTab?.navigationError = nil
        navigationService.reload()
    }

    func retryFailedNavigation() {
        guard let tab = activeTab else { return }

        let url = tab.navigationError?.url ?? tab.displayURL
        tab.navigationError = nil
        chromeController.expand()

        if let url {
            tabManager.loadInActiveTab(url: url)
        } else {
            tab.webView?.reload()
        }
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
        searchService.clearSearchSuggestions()
        chromeController.expand()
    }

    func stopLoading() {
        navigationService.stopLoading()
    }

    func beginTabSwipe(direction: CGFloat) {
        guard isTabSwipeActive == false else { return }
        guard direction == 1 || direction == -1 else { return }
        guard tabManager.tabCount > 1 else { return }

        tabSwipeDirection = direction
        tabSwipeTargetTabID = tabManager.neighborTabID(direction: direction)
        guard tabSwipeTargetTabID != nil else { return }
        isTabSwipeActive = true
        tabSwipeTranslationX = 0
    }

    func updateTabSwipe(translationX: CGFloat) {
        guard isTabSwipeActive else { return }
        let width = UIScreen.main.bounds.width
        tabSwipeTranslationX = translationX.clamped(to: -width...width)
    }

    func endTabSwipe(commit: Bool) {
        guard isTabSwipeActive else { return }
        if commit, let targetID = tabSwipeTargetTabID {
            tabManager.switchToTab(id: targetID)
            syncAddressBarWithActiveTab()
        }
        isTabSwipeActive = false
        tabSwipeTranslationX = 0
        tabSwipeTargetTabID = nil
        tabSwipeDirection = 0
    }

    func completeTabSwipe(commit: Bool, width: CGFloat) {
        guard isTabSwipeActive else { return }

        if commit {
            let targetX = tabSwipeDirection > 0 ? width : -width
            withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.92)) {
                tabSwipeTranslationX = targetX
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                self.endTabSwipe(commit: true)
            }
        } else {
            withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.86)) {
                tabSwipeTranslationX = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                self.endTabSwipe(commit: false)
            }
        }
    }

    func requestDownload(_ pendingDownload: PendingDownload) {
        self.pendingDownload = pendingDownload
        chromeController.expand()
    }

    func confirmPendingDownload(id: UUID) {
        guard pendingDownload?.id == id, let pendingDownload else { return }
        downloadManager.startDownload(
            url: pendingDownload.url,
            suggestedFilename: pendingDownload.suggestedFilename
        )
        self.pendingDownload = nil
    }

    func cancelPendingDownload(id: UUID) {
        guard pendingDownload?.id == id else { return }
        pendingDownload = nil
    }

    func requestLinkActions(_ request: LinkActionRequest) {
        pendingLinkActionRequest = request
        isAddressBarFocused = false
        searchService.clearSearchSuggestions()
        chromeController.expand()
    }

    func openPendingLinkInNewTab(id: UUID) {
        openPendingLink(id: id, browsingMode: .standard)
    }

    func openPendingLinkInPrivateTab(id: UUID) {
        openPendingLink(id: id, browsingMode: .privateBrowsing)
    }

    func dismissPendingLinkActions(id: UUID) {
        guard pendingLinkActionRequest?.id == id else { return }
        pendingLinkActionRequest = nil
    }

    func linkActionsDidDismiss() {
        pendingLinkActionRequest = nil
    }

    private func openPendingLink(id: UUID, browsingMode: BrowsingMode) {
        guard let request = pendingLinkActionRequest, request.id == id else { return }

        let tab: Tab
        if browsingMode == .privateBrowsing {
            tab = tabManager.newPrivateTab(url: request.url)
        } else {
            tab = tabManager.newTab(url: request.url, browsingMode: .standard)
        }

        tab.updateContentBlockerStatus(isEnabled: contentBlockerEnabled)
        tabManager.loadInActiveTab(url: request.url)
        pendingLinkActionRequest = nil
        isAddressBarFocused = false
        searchService.clearSearchSuggestions()
        syncAddressBarWithActiveTab()
        chromeController.expand()
    }

    private func compileContentBlockerRules() {
        let contentBlocker = self.contentBlocker
        Task { [weak self, contentBlocker] in
            do {
                try await contentBlocker.compileRules()
                await MainActor.run {
                    guard let self, self.contentBlockerEnabled else { return }
                    self.recreateWebViewsForContentBlockerConfigurationChange()
                }
            } catch {
                // Ignore error
            }
        }
    }

    private func recreateWebViewsForContentBlockerConfigurationChange() {
        tabManager.discardWebViewsForReconfiguration()
        webViewConfigurationRevision += 1
    }

    func requestJavaScriptDialog(_ request: JavaScriptDialogRequest) {
        guard pendingJavaScriptDialog == nil else {
            queuedJavaScriptDialogs.append(request)
            return
        }

        pendingJavaScriptDialog = request
        chromeController.expand()
    }

    func acceptJavaScriptDialog(id: UUID, promptText: String? = nil) {
        guard let request = pendingJavaScriptDialog, request.id == id else { return }

        request.accept(promptText: promptText)
        if pendingJavaScriptDialog?.id == id {
            pendingJavaScriptDialog = nil
        }
    }

    func cancelJavaScriptDialog(id: UUID) {
        guard let request = pendingJavaScriptDialog, request.id == id else { return }

        request.cancel()
        if pendingJavaScriptDialog?.id == id {
            pendingJavaScriptDialog = nil
        }
    }

    func javaScriptDialogDidDismiss() {
        if let request = pendingJavaScriptDialog {
            request.cancel()
            if pendingJavaScriptDialog?.id == request.id {
                pendingJavaScriptDialog = nil
            }
        }

        presentNextQueuedJavaScriptDialog()
    }

    private func presentNextQueuedJavaScriptDialog() {
        guard pendingJavaScriptDialog == nil, !queuedJavaScriptDialogs.isEmpty else { return }

        pendingJavaScriptDialog = queuedJavaScriptDialogs.removeFirst()
        chromeController.expand()
    }

    private func refreshSiteStatuses() {
        for tab in tabManager.tabs {
            tab.updateContentBlockerStatus(isEnabled: contentBlockerEnabled)
        }
    }
}

// MARK: - Tab Management Helpers
extension BrowserViewModel {
    func selectTab(_ tab: Tab) {
        tabManager.switchToTab(id: tab.id)
        isShowingTabGrid = false
    }
}
