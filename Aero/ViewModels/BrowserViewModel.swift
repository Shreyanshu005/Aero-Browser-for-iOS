






import SwiftUI
import WebKit

@Observable
final class BrowserViewModel {

    var searchSuggestions: [String] = []
    var suggestionsTask: Task<Void, Never>?

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

    var isTabSwipeActive: Bool = false
    var tabSwipeTranslationX: CGFloat = 0
    var tabSwipeTargetTabID: UUID? = nil
    var tabSwipeDirection: CGFloat = 0

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
        clearSearchSuggestions()
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
}
