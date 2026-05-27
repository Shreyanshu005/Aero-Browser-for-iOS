






import SwiftUI
import WebKit
import Observation

@Observable
final class BrowserViewModel {

    var suggestions: [BrowserSuggestion] = []

    @ObservationIgnored
    private let suggestionProvider = LocalSuggestionProvider()

    var tabManager: TabManager
    var historyStore: HistoryStore
    var favoritesStore: FavoritesStore
    var downloadManager: DownloadManager
    var contentBlocker: ContentBlocker


    var isShowingTabGrid: Bool = false
    var isAddressBarFocused: Bool = false
    var addressBarText: String = ""
    var searchEngine: SearchEngine = .google
    var contentBlockerEnabled: Bool = true
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


    var activeTab: Tab? { tabManager.activeTab }
    var chromeMode: BottomChromeMode { chromeController.mode }

    init() {
        self.tabManager = TabManager()
        self.historyStore = HistoryStore()
        self.favoritesStore = FavoritesStore()
        self.downloadManager = DownloadManager()
        self.contentBlocker = ContentBlocker()


        Task {
            await contentBlocker.compileRules()
        }
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
            guard let searchURL = searchEngine.searchURL(for: query) else { return }
            url = searchURL
        }

        tabManager.loadInActiveTab(url: url)
        isAddressBarFocused = false
        chromeController.expand()
    }


    func handleNavigationEvent(_ event: NavigationEvent) {
        switch event {
        case .didStartLoading:
            activeTab?.navigationError = nil
        case .didFinishLoading:
            activeTab?.navigationError = nil
            if let tab = activeTab, let url = tab.url, !url.isInternalPage {
                historyStore.addVisit(url: url, title: tab.title)
            }
            tabManager.saveSession()
        case .didFailLoading(let error):
            let browserError = BrowserError(error: error, url: activeTab?.displayURL)
            guard browserError.shouldDisplay else { return }
            activeTab?.navigationError = browserError
            chromeController.expand()
        case .didUpdateTitle(_), .didUpdateURL(_):
            tabManager.saveSession()
        case .didRequestDownload(let pendingDownload):
            requestDownload(pendingDownload)
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



    func goBack() {
        activeTab?.webView?.goBack()
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
}
