






import SwiftUI
import WebKit

@Observable
final class BrowserViewModel {

    var wikiSuggestions: [WikiSuggestion] = []
    var wikiTask: Task<Void, Never>?

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
        case .didFinishLoading:
            if let tab = activeTab, let url = tab.url, !url.isInternalPage {
                historyStore.addVisit(url: url, title: tab.title)
            }
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
        activeTab?.webView?.reload()
    }

    func stopLoading() {
        activeTab?.webView?.stopLoading()
    }
}
