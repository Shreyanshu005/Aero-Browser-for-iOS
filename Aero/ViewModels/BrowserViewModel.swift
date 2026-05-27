






import SwiftUI
import WebKit
import Observation

@Observable
final class BrowserViewModel {

    var suggestions: [BrowserSuggestion] = []

    @ObservationIgnored
    private let suggestionProvider = LocalSuggestionProvider()

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
    var chromeMode: BottomChromeMode { chromeController.mode }

    init(settingsStore: BrowserSettingsStoring = BrowserSettingsStore()) {
        self.settingsStore = settingsStore
        let settings = settingsStore.loadSettings()
        self.searchEngine = settings.searchEngine
        self.contentBlockerEnabled = settings.contentBlockerEnabled
        self.tabManager = TabManager()
        self.historyStore = HistoryStore()
        self.favoritesStore = FavoritesStore()
        self.downloadManager = DownloadManager()
        self.contentBlocker = ContentBlocker()


        compileContentBlockerRules()
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
            tabManager.saveSession()
        case .didUpdateTitle(_), .didUpdateURL(_):
            tabManager.saveSession()
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
}
