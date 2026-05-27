






import UIKit
import WebKit
import Combine

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
    let tab: Tab
    let onNavigationEvent: (NavigationEvent) -> Void
    private var observations: [NSKeyValueObservation] = []

    init(tab: Tab, onNavigationEvent: @escaping (NavigationEvent) -> Void) {
        self.tab = tab
        self.onNavigationEvent = onNavigationEvent
        super.init()
    }

    deinit {
        observations.removeAll()
    }



    func observeWebView(_ webView: WKWebView) {

        observations.removeAll()
        webView.scrollView.delegate = self

        observations.append(
            webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.tab.estimatedProgress = wv.estimatedProgress
                    self?.onNavigationEvent(.didUpdateProgress(wv.estimatedProgress))
                }
            }
        )

        observations.append(
            webView.observe(\.title, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    let title = wv.title ?? ""
                    self?.tab.title = title
                    self?.onNavigationEvent(.didUpdateTitle(title))
                }
            }
        )

        observations.append(
            webView.observe(\.url, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.tab.url = wv.url
                    self?.tab.isSecure = wv.url?.isSecure ?? false
                    self?.onNavigationEvent(.didUpdateURL(wv.url))
                }
            }
        )

        observations.append(
            webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.tab.canGoBack = wv.canGoBack
                    self?.onNavigationEvent(.didUpdateCanGoBack(wv.canGoBack))
                }
            }
        )

        observations.append(
            webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.tab.canGoForward = wv.canGoForward
                    self?.onNavigationEvent(.didUpdateCanGoForward(wv.canGoForward))
                }
            }
        )

        observations.append(
            webView.observe(\.isLoading, options: .new) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.tab.isLoading = wv.isLoading
                }
            }
        )
    }



    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        tab.isLoading = true
        onNavigationEvent(.didStartLoading)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        tab.isLoading = false
        tab.lastAccessedAt = Date()
        onNavigationEvent(.didFinishLoading)


        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tab.captureSnapshot()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        tab.isLoading = false
        onNavigationEvent(.didFailLoading(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        tab.isLoading = false
        onNavigationEvent(.didFailLoading(error))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload,
           let url = navigationAction.request.url {
            onNavigationEvent(
                .didRequestDownload(
                    PendingDownload(
                        url: url,
                        suggestedFilename: nil,
                        sourceHost: url.displayHost ?? url.host ?? url.absoluteString,
                        mimeType: nil,
                        expectedByteCount: nil
                    )
                )
            )
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard shouldDownload(navigationResponse),
              let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }

        let response = navigationResponse.response
        let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : nil
        onNavigationEvent(
            .didRequestDownload(
                PendingDownload(
                    url: url,
                    suggestedFilename: response.suggestedFilename,
                    sourceHost: url.displayHost ?? url.host ?? url.absoluteString,
                    mimeType: response.mimeType,
                    expectedByteCount: expectedLength
                )
            )
        )
        decisionHandler(.cancel)
    }




    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil || !(navigationAction.targetFrame!.isMainFrame) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        onNavigationEvent(
            .didRequestJavaScriptDialog(
                JavaScriptDialogRequest(
                    kind: .alert,
                    message: message,
                    sourceHost: javascriptDialogSourceHost(frame: frame, webView: webView),
                    completion: .alert(completionHandler)
                )
            )
        )
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        onNavigationEvent(
            .didRequestJavaScriptDialog(
                JavaScriptDialogRequest(
                    kind: .confirm,
                    message: message,
                    sourceHost: javascriptDialogSourceHost(frame: frame, webView: webView),
                    completion: .confirm(completionHandler)
                )
            )
        )
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        onNavigationEvent(
            .didRequestJavaScriptDialog(
                JavaScriptDialogRequest(
                    kind: .prompt(defaultText: defaultText),
                    message: prompt,
                    sourceHost: javascriptDialogSourceHost(frame: frame, webView: webView),
                    completion: .prompt(completionHandler)
                )
            )
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let metrics = WebScrollMetrics(
            offsetY: max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top),
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height
        )
        onNavigationEvent(.didScroll(metrics))
    }

    private func shouldDownload(_ navigationResponse: WKNavigationResponse) -> Bool {
        if navigationResponse.canShowMIMEType == false {
            return true
        }

        guard let httpResponse = navigationResponse.response as? HTTPURLResponse else {
            return false
        }

        let disposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") ?? ""
        return disposition.localizedCaseInsensitiveContains("attachment")
    }

    private func javascriptDialogSourceHost(frame: WKFrameInfo, webView: WKWebView) -> String {
        let url = frame.request.url ?? webView.url
        return url?.displayHost ?? "This Page"
    }
}
