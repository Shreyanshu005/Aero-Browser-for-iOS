






import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let tab: Tab
    let chromeMode: BottomChromeMode
    let isAddressBarFocused: Bool
    let onNavigationEvent: (NavigationEvent) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.createWebView()
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator


        context.coordinator.observeWebView(webView)
        configureScrollInsets(for: webView)


        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        configureScrollInsets(for: webView)

        guard let url = tab.url else { return }

        let currentURL = webView.url
        if currentURL != url && !tab.isLoading {
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(tab: tab, onNavigationEvent: onNavigationEvent)
    }

    private func configureScrollInsets(for webView: WKWebView) {
        let bottomInset: CGFloat
        if isAddressBarFocused {
            bottomInset = BrowserChromeLayout.focusedBottomInset
        } else {
            bottomInset = chromeMode == .compact
                ? BrowserChromeLayout.compactBottomInset
                : BrowserChromeLayout.expandedBottomInset
        }

        webView.scrollView.contentInsetAdjustmentBehavior = chromeMode == .compact && !isAddressBarFocused
            ? .never
            : .automatic
        webView.scrollView.contentInset.bottom = bottomInset
        webView.scrollView.scrollIndicatorInsets.bottom = bottomInset
    }
}



enum NavigationEvent {
    case didStartLoading
    case didFinishLoading
    case didFailLoading(Error)
    case didUpdateProgress(Double)
    case didUpdateTitle(String)
    case didUpdateURL(URL?)
    case didUpdateCanGoBack(Bool)
    case didUpdateCanGoForward(Bool)
    case didScroll(WebScrollMetrics)
}
