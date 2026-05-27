import SwiftUI
import WebKit
import Observation

@Observable
final class BrowserViewModel {

    var searchSuggestions: [String] = []
    @ObservationIgnored
    var suggestionsTask: Task<Void, Never>?
    var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "recent_searches") ?? []
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


    var showMenu: Bool = false
    var showHistory: Bool = false
    var showBookmarks: Bool = false
    var showDownloads: Bool = false
    var showSettings: Bool = false
    var showReaderMode: Bool = false
    var showAddBookmark: Bool = false
    var showFindInPage: Bool = false
    var showTrackerReceipt: Bool = false
    var pendingDownload: PendingDownload?
    var pendingJavaScriptDialog: JavaScriptDialogRequest?


    var activeTab: Tab? { tabManager.activeTab }
    var activeBrowsingMode: BrowsingMode { tabManager.activeBrowsingMode }
    var chromeMode: BottomChromeMode { chromeController.mode }

    var isTabSwipeActive: Bool = false
    var tabSwipeTranslationX: CGFloat = 0
    var tabSwipeTargetTabID: UUID? = nil
    var tabSwipeDirection: CGFloat = 0

    init(
        tabManager: TabManager = TabManager(),
        historyStore: HistoryStore = HistoryStore(),
        favoritesStore: FavoritesStore = FavoritesStore(),
        downloadManager: DownloadManager = DownloadManager(),
        contentBlocker: ContentBlocker = ContentBlocker(),
        settingsStore: BrowserSettingsStoring = BrowserSettingsStore(),
        compileContentBlocker: Bool = true
    ) {
        self.settingsStore = settingsStore
        let settings = settingsStore.loadSettings()
        self.searchEngine = settings.searchEngine
        self.contentBlockerEnabled = settings.contentBlockerEnabled
        self.tabManager = tabManager
        self.historyStore = historyStore
        self.favoritesStore = favoritesStore
        self.downloadManager = downloadManager
        self.contentBlocker = contentBlocker

        refreshSiteStatuses()

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

    deinit {
        pendingJavaScriptDialog?.cancel()
        queuedJavaScriptDialogs.forEach { $0.cancel() }
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

        tabManager.loadInActiveTab(url: url)
        isAddressBarFocused = false
        clearSearchSuggestions()
        clearSuggestions()
        chromeController.expand()
    }

    private func addRecentSearch(_ query: String) {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        recentSearches.removeAll { $0.caseInsensitiveCompare(cleaned) == .orderedSame }
        recentSearches.insert(cleaned, at: 0)
        if recentSearches.count > 20 {
            recentSearches = Array(recentSearches.prefix(20))
        }
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
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

    private func saveSessionForActiveStandardTab() {
        guard activeTab?.browsingMode.isSessionRestorable == true else { return }
        tabManager.saveSession()
    }



    func goBack() {
        if activeTab?.webView?.canGoBack == true {
            activeTab?.webView?.goBack()
            return
        }

        // No more web history: go back to home/new tab.
        if activeTab?.url != nil {
            activeTab?.url = nil
            activeTab?.title = ""
            addressBarText = ""
            isAddressBarFocused = false
            chromeController.expand()
        }
    }

    func goForward() {
        activeTab?.webView?.goForward()
    }

    func reload() {
        if activeTab?.navigationError != nil {
            retryFailedNavigation()
            return
        }

        activeTab?.navigationError = nil
        activeTab?.webView?.reload()
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

    func stopLoading() {
        activeTab?.webView?.stopLoading()
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

    private func compileContentBlockerRules() {
        let contentBlocker = self.contentBlocker
        Task { [weak self, contentBlocker] in
            let didCompile = await contentBlocker.compileRules()
            guard didCompile else { return }

            await MainActor.run {
                guard let self, self.contentBlockerEnabled else { return }
                self.recreateWebViewsForContentBlockerConfigurationChange()
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
