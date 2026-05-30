import WebKit
import UIKit

protocol WebViewBridge: AnyObject {

    var currentURL: URL? { get }

    var currentTitle: String { get }

    var isLoading: Bool { get }

    var canGoBack: Bool { get }

    var canGoForward: Bool { get }

    var estimatedProgress: Double { get }

    func loadURL(_ url: URL)

    func goBack()

    func goForward()

    func reload()

    func stopLoading()

    func evaluateJavaScript(_ script: String) async throws -> Any?

    func setCustomUserAgent(_ userAgent: String?)

    func takeSnapshot() async -> UIImage?
}

final class WKWebViewBridge: WebViewBridge {

    private weak var webView: WKWebView?

    init(webView: WKWebView) {
        self.webView = webView
    }

    var currentURL: URL? {
        webView?.url
    }

    var currentTitle: String {
        webView?.title ?? ""
    }

    var isLoading: Bool {
        webView?.isLoading ?? false
    }

    var canGoBack: Bool {
        webView?.canGoBack ?? false
    }

    var canGoForward: Bool {
        webView?.canGoForward ?? false
    }

    var estimatedProgress: Double {
        webView?.estimatedProgress ?? 0.0
    }

    func loadURL(_ url: URL) {
        let request = URLRequest(url: url)
        webView?.load(request)
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    func evaluateJavaScript(_ script: String) async throws -> Any? {
        guard let webView = webView else {
            throw WebViewBridgeError.webViewDeallocated
        }
        return try await webView.evaluateJavaScript(script)
    }

    func setCustomUserAgent(_ userAgent: String?) {
        webView?.customUserAgent = userAgent
    }

    func takeSnapshot() async -> UIImage? {
        guard let webView = webView else { return nil }
        let configuration = WKSnapshotConfiguration()
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

enum WebViewBridgeError: LocalizedError {

    case webViewDeallocated

    var errorDescription: String? {
        switch self {
        case .webViewDeallocated:
            return "The web view is no longer available."
        }
    }
}
