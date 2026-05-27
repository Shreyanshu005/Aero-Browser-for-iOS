import SwiftUI

extension BrowserViewModel {
    var canReopenLastClosedTab: Bool {
        tabManager.canReopenLastClosedTab
    }

    func showTabGrid() {
        activeTab?.captureSnapshot()
        chromeController.expand()
        withAnimation(AeroAnimation.snappy) {
            isShowingTabGrid = true
        }
    }

    func hideTabGrid() {
        withAnimation(AeroAnimation.snappy) {
            isShowingTabGrid = false
        }
    }

    func selectTab(_ tab: Tab) {
        tabManager.switchToTab(id: tab.id)
        chromeController.expand()
        hideTabGrid()
    }

    func switchBrowsingMode(_ browsingMode: BrowsingMode) {
        tabManager.switchBrowsingMode(browsingMode)
        chromeController.expand()
        addressBarText = ""
        clearSuggestions()
    }

    func newTab() {
        tabManager.newTab()
        chromeController.expand()
        hideTabGrid()
        addressBarText = ""
        isAddressBarFocused = true
    }

    func newPrivateTab() {
        tabManager.newPrivateTab()
        chromeController.expand()
        hideTabGrid()
        addressBarText = ""
        isAddressBarFocused = true
    }

    func closeTab(_ tab: Tab) {
        withAnimation(AeroAnimation.snappy) {
            tabManager.closeTab(id: tab.id)
        }
    }

    func reopenLastClosedTab() {
        guard tabManager.canReopenLastClosedTab else { return }

        withAnimation(AeroAnimation.snappy) {
            _ = tabManager.reopenLastClosedTab()
            isShowingTabGrid = false
        }
        isAddressBarFocused = false
        syncAddressBarWithActiveTab()
        chromeController.expand()
    }
}
