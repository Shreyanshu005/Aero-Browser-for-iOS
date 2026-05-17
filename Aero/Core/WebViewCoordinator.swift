






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

        updateThemeColor(from: webView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tab.captureSnapshot()
        }
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

        decisionHandler(.allow)
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let metrics = WebScrollMetrics(
            offsetY: max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top),
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height
        )
        onNavigationEvent(.didScroll(metrics))
    }
}
