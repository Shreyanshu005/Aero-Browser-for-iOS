import SwiftUI

extension BrowserViewModel {
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

    func newTab() {
        let tab = tabManager.newTab()
        tab.updateContentBlockerStatus(isEnabled: contentBlockerEnabled)
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
}
