






import UIKit
import WebKit
import Combine

final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKDownloadDelegate, WKScriptMessageHandler {
    let tab: Tab
    let onNavigationEvent: (NavigationEvent) -> Void
    let downloadManager: DownloadManager
    private let externalURLPolicy: ExternalURLPolicy
    private let externalURLOpener: ExternalURLOpening
    private var observations: [NSKeyValueObservation] = []
    private weak var refreshControl: UIRefreshControl?
    private var downloadMap: [ObjectIdentifier: UUID] = [:]
    private var downloadProgressObservers: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]
    private let passkeyMessageName = "passkeyRequested"
    private var mainFrameNavigationHost: String?
    private var latestServerCertificateSummary: CertificateSummary?

    init(
        tab: Tab,
        onNavigationEvent: @escaping (NavigationEvent) -> Void,
        downloadManager: DownloadManager,
        externalURLPolicy: ExternalURLPolicy = ExternalURLPolicy(),
        externalURLOpener: ExternalURLOpening = UIApplicationExternalURLOpener()
    ) {
        self.tab = tab
        self.onNavigationEvent = onNavigationEvent
        self.downloadManager = downloadManager
        self.externalURLPolicy = externalURLPolicy
        self.externalURLOpener = externalURLOpener
        super.init()
    }

    deinit {
        observations.removeAll()
    }



    func observeWebView(_ webView: WKWebView) {

        observations.removeAll()
        webView.scrollView.delegate = self
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
                    guard let self else { return }
                    self.tab.updatePageStatus(url: wv.url, isSecure: wv.url?.isSecure ?? false)
                    if let certificateSummary = self.latestServerCertificateSummary,
                       certificateSummary.matches(host: wv.url?.host) {
                        self.tab.updateServerCertificateSummary(certificateSummary)
                    }
                    self.onNavigationEvent(.didUpdateURL(wv.url))
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
        // Avoid duplicate handlers/scripts.
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

        updateThemeColor(from: webView)
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

    private func updateThemeColor(from webView: WKWebView) {
        let js = """
        (function() {
          try {
            var meta = document.querySelector('meta[name="theme-color"]');
            if (meta && meta.content) return meta.content;
            var bodyBg = window.getComputedStyle(document.body).backgroundColor;
            if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') return bodyBg;
            var docBg = window.getComputedStyle(document.documentElement).backgroundColor;
            if (docBg) return docBg;
          } catch (e) {}
          return null;
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            let color = Self.parseCSSColor(result as? String) ?? UIColor.systemBackground
            DispatchQueue.main.async {
                self.tab.pageBackgroundColor = color
                webView.scrollView.backgroundColor = color
                webView.backgroundColor = color
                if #available(iOS 15.0, *) {
                    webView.underPageBackgroundColor = color
                }
            }
        }
    }

    private static func parseCSSColor(_ string: String?) -> UIColor? {
        guard var s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        s = s.lowercased()

        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            func hexToInt(_ sub: Substring) -> Int? { Int(sub, radix: 16) }
            if hex.count == 3,
               let r = hexToInt(hex.prefix(1)),
               let g = hexToInt(hex.dropFirst(1).prefix(1)),
               let b = hexToInt(hex.dropFirst(2).prefix(1)) {
                return UIColor(
                    red: CGFloat(r) / 15.0,
                    green: CGFloat(g) / 15.0,
                    blue: CGFloat(b) / 15.0,
                    alpha: 1
                )
            }
            if hex.count == 6,
               let r = hexToInt(hex.prefix(2)),
               let g = hexToInt(hex.dropFirst(2).prefix(2)),
               let b = hexToInt(hex.dropFirst(4).prefix(2)) {
                return UIColor(
                    red: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: 1
                )
            }
            return nil
        }

        if s.hasPrefix("rgb(") || s.hasPrefix("rgba(") {
            let start = s.firstIndex(of: "(")
            let end = s.lastIndex(of: ")")
            guard let start, let end, start < end else { return nil }
            let inner = s[s.index(after: start)..<end]
            let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3 else { return nil }

            func parseComponent(_ str: String) -> CGFloat? {
                if str.hasSuffix("%") {
                    let n = str.dropLast()
                    guard let v = Double(n) else { return nil }
                    return CGFloat(v / 100.0)
                }
                guard let v = Double(str) else { return nil }
                return CGFloat(v / 255.0)
            }

            guard let r = parseComponent(parts[0]),
                  let g = parseComponent(parts[1]),
                  let b = parseComponent(parts[2]) else { return nil }

            let a: CGFloat = {
                guard parts.count >= 4, let v = Double(parts[3]) else { return 1 }
                return CGFloat(max(0, min(1, v)))
            }()

            return UIColor(red: r, green: g, blue: b, alpha: a)
        }

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
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host
        if shouldCaptureServerTrust(for: host, webView: webView),
           let certificateSummary = CertificateSummaryParser.summary(from: serverTrust, host: host) {
            latestServerCertificateSummary = certificateSummary
            tab.updateServerCertificateSummary(certificateSummary)
        }

        completionHandler(.performDefaultHandling, nil)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let isMainFrameNavigation = navigationAction.targetFrame?.isMainFrame ?? true
        if isMainFrameNavigation {
            prepareForMainFrameNavigation(to: navigationAction.request.url)
        }

        if #available(iOS 14.5, *) {
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
        }

        switch externalURLPolicy.decision(for: navigationAction.request.url) {
        case .allowInWebView:
            decisionHandler(.allow)
        case .openExternally(let url):
            if shouldOpenExternalURL(for: navigationAction) {
                externalURLOpener.open(url)
            }
            decisionHandler(.cancel)
        case .cancel:
            decisionHandler(.cancel)
        }
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

    // MARK: - WKDownload bridge

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        attach(download: download, sourceURL: navigationAction.request.url)
    }

    @available(iOS 14.5, *)
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        attach(download: download, sourceURL: navigationResponse.response.url)
    }

    @available(iOS 14.5, *)
    private func attach(download: WKDownload, sourceURL: URL?) {
        download.delegate = self

        let key = ObjectIdentifier(download)
        if downloadMap[key] == nil {
            let url = sourceURL ?? URL(string: "about:blank")!
            let id = downloadManager.startWebKitDownload(
                sourceURL: url,
                filename: url.lastPathComponent.isEmpty ? "Download" : url.lastPathComponent
            )
            downloadMap[key] = id

            downloadProgressObservers[key] = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
                guard let self, let fraction = change.newValue else { return }
                guard let mappedID = self.downloadMap[key] else { return }
                self.downloadManager.updateWebKitDownloadProgress(id: mappedID, progress: fraction)
            }
        }
    }

    @available(iOS 14.5, *)
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destination = downloadsDir.appendingPathComponent(suggestedFilename)
        // Avoid failures when a file with the same name already exists.
        try? FileManager.default.removeItem(at: destination)
        downloadDestinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)

        let key = ObjectIdentifier(download)
        if let id = downloadMap[key],
           let index = downloadManager.downloads.firstIndex(where: { $0.id == id }) {
            downloadManager.downloads[index].filename = suggestedFilename
        }
    }

    @available(iOS 14.5, *)
    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        defer {
            downloadMap.removeValue(forKey: key)
            downloadProgressObservers.removeValue(forKey: key)
            downloadDestinations.removeValue(forKey: key)
        }

        guard let id = downloadMap[key],
              let fileURL = downloadDestinations[key] else {
            return
        }
        downloadManager.completeWebKitDownload(id: id, localURL: fileURL)
    }

    @available(iOS 14.5, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        defer {
            downloadMap.removeValue(forKey: key)
            downloadProgressObservers.removeValue(forKey: key)
            downloadDestinations.removeValue(forKey: key)
        }

        if let id = downloadMap[key] {
            downloadManager.failWebKitDownload(id: id, error: error)
        }
    }




    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame?.isMainFrame != true {
            tab.recordPopupAttempt()
            switch externalURLPolicy.decision(for: navigationAction.request.url) {
            case .allowInWebView:
                webView.load(navigationAction.request)
            case .openExternally(let url):
                externalURLOpener.open(url)
            case .cancel:
                break
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let request = LinkActionRequest(url: elementInfo.linkURL) else {
            completionHandler(nil)
            return
        }

        completionHandler(nil)
        DispatchQueue.main.async { [onNavigationEvent] in
            onNavigationEvent(.didRequestLinkActions(request))
        }
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

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        tab.recordMediaCaptureRequest(type.siteMediaCaptureType)
        decisionHandler(.prompt)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let metrics = WebScrollMetrics(
            offsetY: max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top),
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height
        )
        onNavigationEvent(.didScroll(metrics))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == passkeyMessageName else { return }
        // Many sites (like X.com) proactively check for passkeys on load.
        // Opening Safari automatically here is extremely disruptive.
        print("[Aero] Website requested passkey via WebAuthn.")
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

    private func shouldOpenExternalURL(for navigationAction: WKNavigationAction) -> Bool {
        navigationAction.targetFrame?.isMainFrame != false
    }

    private func javascriptDialogSourceHost(frame: WKFrameInfo, webView: WKWebView) -> String {
        let url = frame.request.url ?? webView.url
        return url?.displayHost ?? "This Page"
    }

    private func prepareForMainFrameNavigation(to url: URL?) {
        mainFrameNavigationHost = url?.host

        if let latestServerCertificateSummary,
           (!latestServerCertificateSummary.matches(host: url?.host) || url?.scheme?.lowercased() != "https") {
            self.latestServerCertificateSummary = nil
            tab.updateServerCertificateSummary(nil)
        }
    }

    private func shouldCaptureServerTrust(for host: String, webView: WKWebView) -> Bool {
        guard let normalizedHost = normalizedSecurityHost(host) else { return false }

        let candidateHosts = [
            mainFrameNavigationHost,
            webView.url?.host,
            tab.url?.host,
        ]

        return candidateHosts.contains { candidate in
            normalizedSecurityHost(candidate) == normalizedHost
        }
    }

    private func normalizedSecurityHost(_ host: String?) -> String? {
        guard let host, !host.isEmpty else { return nil }
        return host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }
}

private extension WKMediaCaptureType {
    var siteMediaCaptureType: SiteMediaCaptureType {
        switch self {
        case .camera:
            return .camera
        case .microphone:
            return .microphone
        case .cameraAndMicrophone:
            return .cameraAndMicrophone
        @unknown default:
            return .cameraAndMicrophone
        }
    }
}
