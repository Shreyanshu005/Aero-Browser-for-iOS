import Testing
@testable import Aero

struct TabManagerTests {

    @Test func newTabInsertsAtFrontAndActivates() {
        let manager = TabManager()
        let initialActive = manager.activeTab?.id

        let new = manager.newTab()

        #expect(manager.tabs.first?.id == new.id)
        #expect(manager.activeTab?.id == new.id)
        #expect(manager.tabs.contains(where: { $0.id == initialActive }) == true)
    }

    @Test func closeTabRemovesAndKeepsValidActiveIndex() {
        let manager = TabManager()
        let t1 = manager.newTab()
        let t2 = manager.newTab()

        #expect(manager.activeTab?.id == t2.id)
        manager.closeTab(id: t2.id)
        #expect(manager.tabs.contains(where: { $0.id == t2.id }) == false)
        #expect(manager.activeTab != nil)
        #expect(manager.activeTabIndex >= 0 && manager.activeTabIndex < manager.tabs.count)
        #expect(manager.tabs.contains(where: { $0.id == t1.id }) == true)
    }

    @Test func closeAllTabsLeavesSingleNewTab() {
        let manager = TabManager()
        _ = manager.newTab()
        _ = manager.newTab()

        manager.closeAllTabs()

        #expect(manager.tabs.count == 1)
        #expect(manager.activeTabIndex == 0)
        #expect(manager.activeTab != nil)
    }

    @Test func switchToTabUpdatesActiveTab() {
        let manager = TabManager()
        let t1 = manager.newTab()
        let t2 = manager.newTab()

        manager.switchToTab(id: t1.id)
        #expect(manager.activeTab?.id == t1.id)

        manager.switchToTab(id: t2.id)
        #expect(manager.activeTab?.id == t2.id)
    }
}

