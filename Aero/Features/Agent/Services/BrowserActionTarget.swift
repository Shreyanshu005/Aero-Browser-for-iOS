import Foundation
import WebKit

enum BrowserActionExecutionError: Error {
    case missingWebView
}

@MainActor
protocol BrowserActionTarget: AnyObject {
    var browserActionTabID: UUID? { get }
    var browserActionPageURL: URL? { get }
    var browserActionPageTitle: String? { get }
    var browserActionIsLoading: Bool { get }
    var browserActionCanGoBack: Bool { get }
    var browserActionCanGoForward: Bool { get }
    var browserActionHasWebView: Bool { get }

    func browserActionOpenURL(_ url: URL)
    func browserActionGoBack()
    func browserActionGoForward()
    func browserActionReload()
    func browserActionStopLoading()
    func browserActionEvaluateJavaScript(_ javaScript: String) async throws -> Any?
}

extension BrowserViewModel: BrowserActionTarget {
    var browserActionTabID: UUID? {
        activeTab?.id
    }

    var browserActionPageURL: URL? {
        activeTab?.displayURL
    }

    var browserActionPageTitle: String? {
        activeTab?.displayTitle
    }

    var browserActionIsLoading: Bool {
        activeTab?.isLoading ?? false
    }

    var browserActionCanGoBack: Bool {
        activeTab?.webView?.canGoBack ?? activeTab?.canGoBack ?? false
    }

    var browserActionCanGoForward: Bool {
        activeTab?.webView?.canGoForward ?? activeTab?.canGoForward ?? false
    }

    var browserActionHasWebView: Bool {
        activeTab?.webView != nil
    }

    func browserActionOpenURL(_ url: URL) {
        tabManager.loadInActiveTab(url: url)
        isAddressBarFocused = false
        searchService.clearSearchSuggestions()
        chromeController.expand()
    }

    func browserActionGoBack() {
        goBack()
    }

    func browserActionGoForward() {
        goForward()
    }

    func browserActionReload() {
        reload()
    }

    func browserActionStopLoading() {
        stopLoading()
    }

    func browserActionEvaluateJavaScript(_ javaScript: String) async throws -> Any? {
        guard let webView = activeTab?.webView else {
            throw BrowserActionExecutionError.missingWebView
        }

        return try await webView.evaluateBrowserActionJavaScript(javaScript)
    }
}

extension Tab: BrowserActionTarget {
    var browserActionTabID: UUID? {
        id
    }

    var browserActionPageURL: URL? {
        displayURL
    }

    var browserActionPageTitle: String? {
        displayTitle
    }

    var browserActionIsLoading: Bool {
        isLoading
    }

    var browserActionCanGoBack: Bool {
        webView?.canGoBack ?? canGoBack
    }

    var browserActionCanGoForward: Bool {
        webView?.canGoForward ?? canGoForward
    }

    var browserActionHasWebView: Bool {
        webView != nil
    }

    func browserActionOpenURL(_ url: URL) {
        navigationError = nil
        updatePageStatus(url: url, isSecure: url.isSecure)
        webView?.load(URLRequest(url: url))
    }

    func browserActionGoBack() {
        webView?.goBack()
    }

    func browserActionGoForward() {
        webView?.goForward()
    }

    func browserActionReload() {
        webView?.reload()
    }

    func browserActionStopLoading() {
        webView?.stopLoading()
    }

    func browserActionEvaluateJavaScript(_ javaScript: String) async throws -> Any? {
        guard let webView else {
            throw BrowserActionExecutionError.missingWebView
        }

        return try await webView.evaluateBrowserActionJavaScript(javaScript)
    }
}

private extension WKWebView {
    func evaluateBrowserActionJavaScript(_ javaScript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
            evaluateJavaScript(javaScript) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
