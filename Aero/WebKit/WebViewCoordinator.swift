import UIKit
import WebKit
import Combine

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    let tab: Tab
    let onNavigationEvent: (NavigationEvent) -> Void
    let downloadManager: DownloadManager
    private var observations: [NSKeyValueObservation] = []
    private weak var refreshControl: UIRefreshControl?
    private lazy var scrollCoordinator = ScrollCoordinator { [weak self] metrics in
        self?.onNavigationEvent(.didScroll(metrics))
    }
    private lazy var downloadCoordinator = DownloadCoordinator(downloadManager: downloadManager)
    private let passkeyMessageName = "passkeyRequested"

    init(
        tab: Tab,
        onNavigationEvent: @escaping (NavigationEvent) -> Void,
        downloadManager: DownloadManager
    ) {
        self.tab = tab
        self.onNavigationEvent = onNavigationEvent
        self.downloadManager = downloadManager
        super.init()
    }

    deinit {
        observations.removeAll()
    }

    func observeWebView(_ webView: WKWebView) {

        observations.removeAll()
        webView.scrollView.delegate = scrollCoordinator
        webView.scrollView.alwaysBounceVertical = true

        installPasskeyDetectionIfNeeded(into: webView)

        if webView.scrollView.refreshControl == nil {
            let rc = UIRefreshControl()
            rc.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
            webView.scrollView.refreshControl = rc
            refreshControl = rc
        } else {
            refreshControl = webView.scrollView.refreshControl
        }

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

    private func installPasskeyDetectionIfNeeded(into webView: WKWebView) {
        let ucc = webView.configuration.userContentController
        ucc.removeScriptMessageHandler(forName: passkeyMessageName)
        ucc.add(self, name: passkeyMessageName)

        let source = """
        (function() {
          try {
            if (!window.PublicKeyCredential || !navigator.credentials) return;
            const handler = function() {
              try { window.webkit.messageHandlers.\(passkeyMessageName).postMessage({type:'webauthn'}); } catch(e) {}
            };
            const origGet = navigator.credentials.get.bind(navigator.credentials);
            navigator.credentials.get = function(options) {
              try { if (options && options.publicKey) handler(); } catch(e) {}
              return origGet(options);
            };
            const origCreate = navigator.credentials.create.bind(navigator.credentials);
            navigator.credentials.create = function(options) {
              try { if (options && options.publicKey) handler(); } catch(e) {}
              return origCreate(options);
            };
          } catch(e) {}
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.removeAllUserScripts()
        ucc.addUserScript(script)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        tab.isLoading = true
        onNavigationEvent(.didStartLoading)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        tab.isLoading = false
        tab.lastAccessedAt = Date()
        onNavigationEvent(.didFinishLoading)

        ThemeExtractor.updateThemeColor(from: webView, for: tab)
        fetchFaviconIfNeeded(from: webView)
        refreshControl?.endRefreshing()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tab.captureSnapshot()
        }
    }

    private func fetchFaviconIfNeeded(from webView: WKWebView) {
        guard let url = webView.url, let host = url.host else { return }
        guard tab.faviconHost?.caseInsensitiveCompare(host) != .orderedSame else { return }

        tab.faviconHost = host
        tab.favicon = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }

            let iconURL = await self.bestFaviconURL(for: webView, pageURL: url) ?? self.defaultFaviconURL(for: url)
            guard let iconURL else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: iconURL)
                guard let image = UIImage(data: data) else { return }
                await MainActor.run {
                    if self.tab.faviconHost?.caseInsensitiveCompare(host) == .orderedSame {
                        self.tab.favicon = image
                    }
                }
            } catch {
                return
            }
        }
    }

    private func defaultFaviconURL(for pageURL: URL) -> URL? {
        var comps = URLComponents()
        comps.scheme = pageURL.scheme
        comps.host = pageURL.host
        comps.path = "/favicon.ico"
        return comps.url
    }

    private func bestFaviconURL(for webView: WKWebView, pageURL: URL) async -> URL? {
        let js = """
        (function(){
          var el = document.querySelector('link[rel~=\"icon\"]') || document.querySelector('link[rel=\"shortcut icon\"]');
          return el ? el.href : null;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(js)
            if let href = result as? String, let url = URL(string: href) {
                return url
            }
        } catch { }

        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        tab.isLoading = false
        onNavigationEvent(.didFailLoading(error))
        refreshControl?.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        tab.isLoading = false
        onNavigationEvent(.didFailLoading(error))
        refreshControl?.endRefreshing()
    }

    @objc private func handleRefreshControl() {
        tab.webView?.reload()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if #available(iOS 14.5, *) {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }

        if let http = navigationResponse.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
           disposition.contains("attachment") {
            if #available(iOS 14.5, *) {
                decisionHandler(.download)
                return
            } else {
                downloadManager.startDownload(url: url, suggestedFilename: http.suggestedFilename)
                decisionHandler(.cancel)
                return
            }
        }

        if navigationResponse.canShowMIMEType == false {
            if #available(iOS 14.5, *) {
                decisionHandler(.download)
                return
            } else {
                downloadManager.startDownload(url: url, suggestedFilename: navigationResponse.response.suggestedFilename)
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }

    // MARK: - WKDownload bridge

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        downloadCoordinator.attach(download: download, sourceURL: navigationAction.request.url)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        downloadCoordinator.attach(download: download, sourceURL: navigationResponse.response.url)
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

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == passkeyMessageName else { return }
        guard let url = tab.webView?.url else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}
