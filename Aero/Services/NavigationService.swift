import Foundation

@Observable
final class NavigationService {
    var tabManager: TabManager
    var chromeController: BrowserChromeController
    
    init(tabManager: TabManager, chromeController: BrowserChromeController) {
        self.tabManager = tabManager
        self.chromeController = chromeController
    }
    
    var activeTab: Tab? { tabManager.activeTab }
    
    func goBack() {
        if activeTab?.webView?.canGoBack == true {
            activeTab?.webView?.goBack()
            return
        }
        
        if activeTab?.url != nil {
            activeTab?.url = nil
            activeTab?.title = ""
            chromeController.expand()
        }
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
}
