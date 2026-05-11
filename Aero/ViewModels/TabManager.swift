






import SwiftUI
import WebKit

@Observable
final class TabManager {
    var tabs: [Tab] = []
    var activeTabIndex: Int = 0

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
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        return tab
    }


    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }


        tabs[index].webView?.stopLoading()
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


    func closeAllTabs() {
        for tab in tabs {
            tab.webView?.stopLoading()
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
