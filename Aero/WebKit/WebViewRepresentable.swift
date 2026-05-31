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
    let downloadManager: DownloadManager

    func makeUIView(context: Context) -> WKWebView {
        let webView = tab.createWebView(
            contentBlocker: contentBlocker,
            isContentBlockerEnabled: isContentBlockerEnabled
        )
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        context.coordinator.observeWebView(webView)
        configureAppearance(for: webView)
        configureScrollInsets(for: webView)

        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        configureAppearance(for: webView)
        configureScrollInsets(for: webView)
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(tab: tab, onNavigationEvent: onNavigationEvent, downloadManager: downloadManager)
    }

    private func configureScrollInsets(for webView: WKWebView) {
        let scrollView = webView.scrollView
        let oldTopInset = scrollView.contentInset.top
        let oldBottomInset = scrollView.contentInset.bottom
        let oldVisibleOffset = scrollView.contentOffset.y + oldTopInset

        let topInset: CGFloat = {
            if chromeMode == .compact && !isAddressBarFocused {
                return BrowserChromeLayout.compactTopInset
            }
            return 0
        }()

        let bottomInset: CGFloat = {
            if isAddressBarFocused { return BrowserChromeLayout.focusedBottomInset }
            return chromeMode == .compact
                ? BrowserChromeLayout.compactBottomInset
                : BrowserChromeLayout.expandedBottomInset
        }()

        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset.top = topInset
        scrollView.contentInset.bottom = bottomInset
        scrollView.scrollIndicatorInsets.top = topInset
        scrollView.scrollIndicatorInsets.bottom = bottomInset

        guard abs(oldTopInset - topInset) > 0.5 || abs(oldBottomInset - bottomInset) > 0.5 else { return }

        let minOffsetY = -topInset
        let preservedOffsetY = max(minOffsetY, oldVisibleOffset - topInset)
        if scrollView.contentOffset.y != preservedOffsetY {
            scrollView.setContentOffset(
                CGPoint(x: scrollView.contentOffset.x, y: preservedOffsetY),
                animated: false
            )
        }
    }

    private func configureAppearance(for webView: WKWebView) {
        let bg = tab.pageBackgroundColor
        webView.scrollView.backgroundColor = bg
        webView.backgroundColor = bg
        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = bg
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
    case didRequestJavaScriptDialog(JavaScriptDialogRequest)
    case didRequestLinkActions(LinkActionRequest)
    case didScroll(WebScrollMetrics)
}
