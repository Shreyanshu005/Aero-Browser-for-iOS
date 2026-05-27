






import SwiftUI
import WebKit

@Observable
@MainActor
final class TabManager {
    private(set) var tabs: [Tab] = []
    private(set) var activeTabIndex: Int = 0

    static let maxTabs = 100

    var activeTab: Tab? {
        guard !tabs.isEmpty, activeTabIndex >= 0, activeTabIndex < tabs.count else {
            return nil
        }
        return tabs[activeTabIndex]
    }

    var tabCount: Int { tabs.count }

    init() {

        let tab = Tab()
        tabs.append(tab)
    }




    @discardableResult
    func newTab(url: URL? = nil) -> Tab {
        guard tabs.count < TabManager.maxTabs else {
            return tabs[activeTabIndex]
        }

        let tab = Tab(url: url)
        tabs.insert(tab, at: 0)
        activeTabIndex = 0
        return tab
    }


    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }


        if let wv = tabs[index].webView {
            WebViewPool.shared.enqueue(wv)
        }
        tabs[index].webView = nil

        tabs.remove(at: index)

        if tabs.isEmpty {

            newTab()
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        } else if index <= activeTabIndex && activeTabIndex > 0 {
            activeTabIndex -= 1
        }
    }


    func switchToTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        activeTab?.captureSnapshot()
        activeTabIndex = index
        tabs[index].lastAccessedAt = Date()
    }

    func switchToPreviousTab() {
        guard !tabs.isEmpty else { return }
        let nextIndex = min(activeTabIndex + 1, tabs.count - 1)
        guard nextIndex != activeTabIndex else { return }
        switchToTab(id: tabs[nextIndex].id)
    }

    func switchToNextTab() {
        guard !tabs.isEmpty else { return }
        let nextIndex = max(activeTabIndex - 1, 0)
        guard nextIndex != activeTabIndex else { return }
        switchToTab(id: tabs[nextIndex].id)
    }

    func neighborTabID(direction: CGFloat) -> UUID? {
        guard direction == 1 || direction == -1 else { return nil }
        guard !tabs.isEmpty else { return nil }

        if direction == 1 {
            let index = min(activeTabIndex + 1, tabs.count - 1)
            guard index != activeTabIndex else { return nil }
            return tabs[index].id
        } else {
            let index = max(activeTabIndex - 1, 0)
            guard index != activeTabIndex else { return nil }
            return tabs[index].id
        }
    }


    func closeAllTabs() {
        for tab in tabs {
            if let wv = tab.webView {
                WebViewPool.shared.enqueue(wv)
            }
            tab.webView = nil
        }
        tabs.removeAll()
        newTab()
    }


    func loadInActiveTab(url: URL) {
        guard let tab = activeTab else {
            newTab(url: url)
            return
        }

        tab.url = url
        tab.webView?.load(URLRequest(url: url))
    }
}
