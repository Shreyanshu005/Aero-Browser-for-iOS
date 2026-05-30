import WebKit

@MainActor
final class WebViewPool {
    static let shared = WebViewPool()

    private let maxPoolSize = 3
    private var availableWebViews: [WKWebView] = []

    private let configuration: WKWebViewConfiguration

    private init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all

        self.configuration = config
    }

    func dequeue() -> WKWebView {
        if !availableWebViews.isEmpty {
            let webView = availableWebViews.removeLast()
            webView.stopLoading()
            webView.load(URLRequest(url: URL(string: "about:blank")!))
            webView.customUserAgent = nil
            webView.scrollView.delegate = nil
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            return webView
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func enqueue(_ webView: WKWebView) {
        webView.stopLoading()
        webView.load(URLRequest(url: URL(string: "about:blank")!))
        webView.customUserAgent = nil
        webView.scrollView.delegate = nil
        webView.navigationDelegate = nil
        webView.uiDelegate = nil

        if availableWebViews.count < maxPoolSize {
            availableWebViews.append(webView)
        }
    }
}
