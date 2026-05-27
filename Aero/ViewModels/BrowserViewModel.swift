






import SwiftUI
import WebKit

@Observable
final class BrowserViewModel {

    private(set) var searchService = SearchService()
    var searchSuggestions: [String] { searchService.searchSuggestions }
    var recentSearches: [String] { searchService.recentSearches }

    var tabManager: TabManager
    var historyStore: HistoryStore
    var favoritesStore: FavoritesStore
    var downloadManager: DownloadManager
    var contentBlocker: ContentBlocker

    private(set) var navigationService: NavigationService!

    var isShowingTabGrid: Bool = false
    var isAddressBarFocused: Bool = false
    var addressBarText: String = ""
    var searchEngine: SearchEngine = .google
    var contentBlockerEnabled: Bool = true
    var chromeController = BrowserChromeController()
    private var contentBlockerApplied: Bool = false


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
    
    var showReaderMode: Bool {
        get { sheetRouter.activeFullScreenCover == .readerMode }
        set { if newValue { sheetRouter.presentFullScreen(.readerMode) } else { sheetRouter.dismissFullScreenCover() } }
    }
    var showFindInPage: Bool {
        get { sheetRouter.activeFullScreenCover == .findInPage }
        set { if newValue { sheetRouter.presentFullScreen(.findInPage) } else { sheetRouter.dismissFullScreenCover() } }
    }


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

        self.navigationService = NavigationService(tabManager: self.tabManager, chromeController: self.chromeController)


        Task {
            await contentBlocker.compileRules()
            await MainActor.run {
                self.refreshContentBlocking()
            }
        }
    }

    func refreshContentBlocking() {
        guard let webView = activeTab?.webView else { return }
        if contentBlockerEnabled {
            if !contentBlockerApplied {
                contentBlocker.apply(to: webView.configuration)
                contentBlockerApplied = true
                webView.reload()
            }
        } else {
            if contentBlockerApplied {
                contentBlocker.remove(from: webView.configuration)
                contentBlockerApplied = false
                webView.reload()
            }
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
            addRecentSearch(query)
            guard let searchURL = searchEngine.searchURL(for: query) else { return }
            url = searchURL
        }

        tabManager.loadInActiveTab(url: url)
        isAddressBarFocused = false
        searchService.clearSearchSuggestions()
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
        navigationService.goBack()
    }

    func goForward() {
        navigationService.goForward()
    }

    func reload() {
        navigationService.reload()
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
}
