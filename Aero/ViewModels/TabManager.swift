import SwiftUI
import WebKit
import Observation

@Observable
final class TabManager {
    var tabs: [Tab] = []
    var activeTabIndex: Int = 0
    private var recentlyClosedTabs: [RestoredTabState] = []

    @ObservationIgnored
    private let sessionStore: SessionStoring

    static let maxTabs = 100
    static let maxRecentlyClosedTabs = 20

    var activeTab: Tab? {
        guard !tabs.isEmpty, activeTabIndex >= 0, activeTabIndex < tabs.count else {
            return nil
        }
        return tabs[activeTabIndex]
    }

    var activeBrowsingMode: BrowsingMode {
        activeTab?.browsingMode ?? .standard
    }

    var tabCount: Int {
        tabCount(in: activeBrowsingMode)
    }

    var recentlyClosedTabCount: Int { recentlyClosedTabs.count }

    var canReopenLastClosedTab: Bool {
        !recentlyClosedTabs.isEmpty && tabs.count < Self.maxTabs
    }

    init(sessionStore: SessionStoring = SessionStore()) {
        self.sessionStore = sessionStore

        if let session = sessionStore.loadSession(),
           !session.tabs.isEmpty {
            restore(session)
        } else {
            tabs.append(Tab())
            saveSession()
        }
    }

    func tabs(in browsingMode: BrowsingMode) -> [Tab] {
        tabs.filter { $0.browsingMode == browsingMode }
    }

    func tabCount(in browsingMode: BrowsingMode) -> Int {
        tabs(in: browsingMode).count
    }

    @discardableResult
    func newTab(url: URL? = nil, browsingMode: BrowsingMode? = nil) -> Tab {
        let mode = browsingMode ?? activeBrowsingMode
        let tab = appendTab(url: url, browsingMode: mode)
        saveSessionIfRestorable(tab)
        return tab
    }

    @discardableResult
    func newPrivateTab(url: URL? = nil) -> Tab {
        newTab(url: url, browsingMode: .privateBrowsing)
    }

    func switchBrowsingMode(_ browsingMode: BrowsingMode) {
        guard activeBrowsingMode != browsingMode else { return }

        activeTab?.captureSnapshot()

        if let index = mostRecentTabIndex(in: browsingMode) {
            activeTabIndex = index
            tabs[index].lastAccessedAt = Date()
            saveSessionIfRestorable(tabs[index])
        } else {
            let tab = appendTab(browsingMode: browsingMode)
            saveSessionIfRestorable(tab)
        }
    }

    @discardableResult
    private func appendTab(url: URL? = nil, browsingMode: BrowsingMode = .standard) -> Tab {
        guard tabs.count < TabManager.maxTabs else {
            if let index = mostRecentTabIndex(in: browsingMode) {
                activeTabIndex = index
                tabs[index].lastAccessedAt = Date()
                return tabs[index]
            }

            activeTabIndex = min(max(activeTabIndex, 0), max(tabs.count - 1, 0))
            return tabs[activeTabIndex]
        }

        let tab = Tab(url: url, browsingMode: browsingMode)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        return tab
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let closedTab = tabs[index]
        let wasActiveTab = index == activeTabIndex
        if closedTab.browsingMode.isSessionRestorable {
            pushRecentlyClosedTab(restoredState(for: closedTab))
        }

        tabs[index].discardWebView()

        tabs.remove(at: index)

        var didCreateRestorableFallback = false

        if tabs.isEmpty {
            appendTab()
            didCreateRestorableFallback = true
        } else if wasActiveTab {
            if let sameModeIndex = nearestTabIndex(in: closedTab.browsingMode, around: index) {
                activeTabIndex = sameModeIndex
            } else if closedTab.browsingMode == .privateBrowsing {
                if let standardIndex = mostRecentTabIndex(in: .standard) {
                    activeTabIndex = standardIndex
                } else {
                    appendTab()
                    didCreateRestorableFallback = true
                }
            } else {
                appendTab()
                didCreateRestorableFallback = true
            }
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }

        activeTabIndex = min(max(activeTabIndex, 0), max(tabs.count - 1, 0))

        if closedTab.browsingMode.isSessionRestorable || didCreateRestorableFallback {
            saveSession()
        }
    }

    @discardableResult
    func reopenLastClosedTab() -> Tab? {
        guard canReopenLastClosedTab else { return nil }

        let state = recentlyClosedTabs.removeLast()
        let tab = Tab(
            url: state.url,
            title: state.title,
            createdAt: state.createdAt,
            lastAccessedAt: state.lastAccessedAt
        )
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        saveSession()
        return tab
    }

    func switchToTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        activeTab?.captureSnapshot()

        activeTabIndex = index
        tabs[index].lastAccessedAt = Date()
        saveSessionIfRestorable(tabs[index])
    }

    func closeAllTabs() {
        for tab in tabs {
            if tab.browsingMode.isSessionRestorable {
                pushRecentlyClosedTab(restoredState(for: tab))
            }
            tab.discardWebView()
        }
        tabs.removeAll()
        appendTab()
        saveSession()
    }

    func discardWebViewsForReconfiguration() {
        for tab in tabs {
            tab.discardWebView()
        }
    }


    func loadInActiveTab(url: URL) {
        guard let tab = activeTab else {
            newTab(url: url, browsingMode: .standard)
            return
        }

        tab.navigationError = nil
        tab.url = url
        tab.webView?.load(URLRequest(url: url))
        saveSessionIfRestorable(tab)
    }

    func saveSession() {
        let restorableTabs = Array(
            tabs
                .filter { $0.browsingMode.isSessionRestorable }
                .prefix(Self.maxTabs)
        )
        let restoredTabs = restorableTabs.map { tab in
            RestoredTabState(
                url: tab.url,
                title: tab.title,
                createdAt: tab.createdAt,
                lastAccessedAt: tab.lastAccessedAt
            )
        }
        let state = BrowserSessionState(
            activeTabIndex: activeRestorableIndex(in: restorableTabs),
            tabs: restoredTabs
        )
        sessionStore.saveSession(state)
    }

    private func restoredState(for tab: Tab) -> RestoredTabState {
        RestoredTabState(
            url: tab.url,
            title: tab.title,
            createdAt: tab.createdAt,
            lastAccessedAt: tab.lastAccessedAt
        )
    }

    private func pushRecentlyClosedTab(_ state: RestoredTabState) {
        recentlyClosedTabs.append(state)
        if recentlyClosedTabs.count > Self.maxRecentlyClosedTabs {
            recentlyClosedTabs.removeFirst(recentlyClosedTabs.count - Self.maxRecentlyClosedTabs)
        }
    }

    private func restore(_ session: BrowserSessionState) {
        tabs = session.tabs
            .prefix(Self.maxTabs)
            .map { state in
                Tab(
                    url: state.url,
                    title: state.title,
                    browsingMode: .standard,
                    createdAt: state.createdAt,
                    lastAccessedAt: state.lastAccessedAt
                )
            }

        if tabs.isEmpty {
            tabs.append(Tab())
            activeTabIndex = 0
        } else {
            activeTabIndex = min(max(session.activeTabIndex, 0), tabs.count - 1)
        }
    }

    private func saveSessionIfRestorable(_ tab: Tab?) {
        guard tab?.browsingMode.isSessionRestorable == true else { return }
        saveSession()
    }

    private func activeRestorableIndex(in restorableTabs: [Tab]) -> Int {
        if let activeID = activeTab?.id,
           let index = restorableTabs.firstIndex(where: { $0.id == activeID }) {
            return index
        }

        if let index = restorableTabs
            .enumerated()
            .max(by: { $0.element.lastAccessedAt < $1.element.lastAccessedAt })?
            .offset {
            return index
        }

        return 0
    }

    private func mostRecentTabIndex(in browsingMode: BrowsingMode) -> Int? {
        tabs.indices
            .filter { tabs[$0].browsingMode == browsingMode }
            .max { tabs[$0].lastAccessedAt < tabs[$1].lastAccessedAt }
    }

    private func nearestTabIndex(in browsingMode: BrowsingMode, around removedIndex: Int) -> Int? {
        tabs.indices
            .filter { tabs[$0].browsingMode == browsingMode }
            .min { lhs, rhs in
                abs(lhs - removedIndex) < abs(rhs - removedIndex)
            }
    }
}
