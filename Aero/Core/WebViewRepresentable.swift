






import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let tab: Tab
    let contentBlocker: ContentBlocker
    let isContentBlockerEnabled: Bool
    let chromeMode: BottomChromeMode
    let isAddressBarFocused: Bool
    let safeAreaInsets: EdgeInsets
    let onNavigationEvent: (NavigationEvent) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.createWebView(
            contentBlocker: contentBlocker,
            isContentBlockerEnabled: isContentBlockerEnabled
        )
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
        let scrollView = webView.scrollView
        let oldTopInset = scrollView.contentInset.top
        let oldVisibleOffset = scrollView.contentOffset.y + oldTopInset

        let topInset = chromeMode == .compact && !isAddressBarFocused
            ? BrowserChromeLayout.compactTopInset
            : safeAreaInsets.top

        let bottomInset: CGFloat
        if isAddressBarFocused {
            bottomInset = BrowserChromeLayout.focusedBottomInset
        } else {
            bottomInset = chromeMode == .compact
                ? BrowserChromeLayout.compactBottomInset
                : BrowserChromeLayout.expandedBottomInset
        }

        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset.top = topInset
        scrollView.contentInset.bottom = bottomInset
        scrollView.scrollIndicatorInsets.top = topInset
        scrollView.scrollIndicatorInsets.bottom = bottomInset

        guard abs(oldTopInset - topInset) > 0.5 else { return }

        let minOffsetY = -topInset
        let preservedOffsetY = max(minOffsetY, oldVisibleOffset - topInset)
        if scrollView.contentOffset.y != preservedOffsetY {
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: preservedOffsetY),
                animated: false
            )
        }
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
    case didRequestDownload(PendingDownload)
    case didScroll(WebScrollMetrics)
}
