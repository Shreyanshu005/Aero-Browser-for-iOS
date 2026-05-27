import WebKit
import UIKit

// MARK: - Protocol

/// Protocol abstracting web view operations for testability and decoupling.
///
/// Views and services should depend on this protocol rather than directly on `WKWebView`,
/// enabling mock implementations for unit tests and preventing tight coupling to WebKit internals.
protocol WebViewBridge: AnyObject {
    /// The URL currently loaded in the web view, if any.
    var currentURL: URL? { get }

    /// The title of the currently loaded page.
    var currentTitle: String { get }

    /// Whether the web view is currently loading content.
    var isLoading: Bool { get }

    /// Whether the web view can navigate backward in its history.
    var canGoBack: Bool { get }

    /// Whether the web view can navigate forward in its history.
    var canGoForward: Bool { get }

    /// The estimated progress of the current page load, from 0.0 to 1.0.
    var estimatedProgress: Double { get }

    /// Loads the specified URL in the web view.
    /// - Parameter url: The URL to load.
    func loadURL(_ url: URL)

    /// Navigates backward in the web view's history.
    func goBack()

    /// Navigates forward in the web view's history.
    func goForward()

    /// Reloads the current page.
    func reload()

    /// Stops the current page load.
    func stopLoading()

    /// Evaluates a JavaScript string in the context of the current page.
    /// - Parameter script: The JavaScript source to evaluate.
    /// - Returns: The result of the script evaluation, or `nil` if none.
    /// - Throws: An error if evaluation fails.
    func evaluateJavaScript(_ script: String) async throws -> Any?

    /// Sets a custom User-Agent string on the web view.
    /// - Parameter userAgent: The user agent string, or `nil` to reset to the default.
    func setCustomUserAgent(_ userAgent: String?)

    /// Captures a snapshot of the web view's visible content.
    /// - Returns: A `UIImage` of the snapshot, or `nil` if capture fails.
    func takeSnapshot() async -> UIImage?
}

// MARK: - Concrete Implementation

/// Concrete bridge wrapping a `WKWebView` instance to implement `WebViewBridge`.
///
/// This class holds a weak reference to its underlying web view so it does not
/// prevent deallocation when the tab is closed.
final class WKWebViewBridge: WebViewBridge {

    // MARK: - Properties

    /// The underlying web view. Held weakly to avoid retain cycles with tab ownership.
    private weak var webView: WKWebView?

    // MARK: - Initialization

    /// Creates a bridge wrapping the given web view.
    /// - Parameter webView: The `WKWebView` to wrap.
    init(webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - WebViewBridge Conformance

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

// MARK: - Errors

/// Errors that can occur during `WKWebViewBridge` operations.
enum WebViewBridgeError: LocalizedError {
    /// The underlying `WKWebView` has been deallocated.
    case webViewDeallocated

    var errorDescription: String? {
        switch self {
        case .webViewDeallocated:
            return "The web view is no longer available."
        }
    }
}
