






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

    var tabCount: Int { tabs.count }
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




    @discardableResult
    func newTab(url: URL? = nil) -> Tab {
        let tab = appendTab(url: url)
        saveSession()
        return tab
    }

    @discardableResult
    private func appendTab(url: URL? = nil) -> Tab {
        guard tabs.count < TabManager.maxTabs else {
            return tabs[activeTabIndex]
        }

        let tab = Tab(url: url)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        return tab
    }


    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        let closedTabState = restoredState(for: tabs[index])
        pushRecentlyClosedTab(closedTabState)

        tabs[index].webView?.stopLoading()
        tabs[index].webView = nil

        tabs.remove(at: index)

        if tabs.isEmpty {

            appendTab()
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index <= activeTabIndex && activeTabIndex > 0 {
            activeTabIndex -= 1
        }

        saveSession()
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
        saveSession()
    }


    func closeAllTabs() {
        for tab in tabs {
            pushRecentlyClosedTab(restoredState(for: tab))
            tab.webView?.stopLoading()
            tab.webView = nil
        }
        tabs.removeAll()
        appendTab()
        saveSession()
    }


    func loadInActiveTab(url: URL) {
        guard let tab = activeTab else {
            newTab(url: url)
            return
        }

        tab.url = url
        tab.webView?.load(URLRequest(url: url))
        saveSession()
    }

    func saveSession() {
        let restoredTabs = tabs.prefix(Self.maxTabs).map { tab in
            RestoredTabState(
                url: tab.url,
                title: tab.title,
                createdAt: tab.createdAt,
                lastAccessedAt: tab.lastAccessedAt
            )
        }
        let state = BrowserSessionState(
            activeTabIndex: min(max(activeTabIndex, 0), max(restoredTabs.count - 1, 0)),
            tabs: Array(restoredTabs)
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
}
