import Foundation
import WebKit
import Observation

@Observable
final class FindInPageService {

    private(set) var currentMatch: Int = 0

    private(set) var totalMatches: Int = 0

    private(set) var lastQuery: String = ""

    private weak var webView: WKWebView?

    private static let highlightCSS = """
    .aero-find-highlight {
        background-color: rgba(255, 230, 0, 0.45) !important;
        border-radius: 2px;
        padding: 0 1px;
    }
    .aero-find-highlight-active {
        background-color: rgba(255, 150, 0, 0.70) !important;
        border-radius: 2px;
        padding: 0 1px;
    }
    """

    private static let styleElementID = "aero-find-in-page-style"

    init(webView: WKWebView?) {
        self.webView = webView
    }

    func findNext(query: String) {
        guard let webView = webView, !query.isEmpty else {
            resetState()
            return
        }

        let isNewQuery = query != lastQuery
        lastQuery = query

        if isNewQuery {
            injectHighlightCSS()
            countMatches(query: query)
        }

        let escapedQuery = query.escapedForJavaScript()

        let js = "window.find('\(escapedQuery)', false, false, true, false, true, false)"
        webView.evaluateJavaScript(js) { [weak self] _, _ in
            guard let self else { return }
            if self.totalMatches > 0 {
                if self.currentMatch < self.totalMatches {
                    self.currentMatch += 1
                } else {
                    self.currentMatch = 1
                }
            }
        }
    }

    func findPrevious(query: String) {
        guard let webView = webView, !query.isEmpty else {
            resetState()
            return
        }

        let isNewQuery = query != lastQuery
        lastQuery = query

        if isNewQuery {
            injectHighlightCSS()
            countMatches(query: query)
        }

        let escapedQuery = query.escapedForJavaScript()

        let js = "window.find('\(escapedQuery)', false, true, true)"
        webView.evaluateJavaScript(js) { [weak self] _, _ in
            guard let self else { return }
            if self.totalMatches > 0 {
                if self.currentMatch > 1 {
                    self.currentMatch -= 1
                } else {
                    self.currentMatch = self.totalMatches
                }
            }
        }
    }

    func clearHighlights() {
        guard let webView = webView else { return }

        let js = """
        (function() {
            window.getSelection().removeAllRanges();
            var style = document.getElementById('\(Self.styleElementID)');
            if (style) style.remove();
        })()
        """
        webView.evaluateJavaScript(js) { _, _ in }
        resetState()
    }

    private func resetState() {
        currentMatch = 0
        totalMatches = 0
        lastQuery = ""
    }

    private func injectHighlightCSS() {
        guard let webView = webView else { return }

        let escapedCSS = Self.highlightCSS
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "'", with: "\\'")

        let js = """
        (function() {
            if (document.getElementById('\(Self.styleElementID)')) return;
            var style = document.createElement('style');
            style.id = '\(Self.styleElementID)';
            style.textContent = '\(escapedCSS)';
            document.head.appendChild(style);
        })()
        """
        webView.evaluateJavaScript(js) { _, _ in }
    }

    private func countMatches(query: String) {
        guard let webView = webView else { return }

        let escapedQuery = query.lowercased().escapedForJavaScript()

        let js = """
        (function() {
            var count = 0;
            var pos = 0;
            var text = document.body.innerText.toLowerCase();
            var query = '\(escapedQuery)';
            if (query.length === 0) return 0;
            while ((pos = text.indexOf(query, pos)) !== -1) {
                count++;
                pos += query.length;
            }
            return count;
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }
            if let count = result as? Int {
                self.totalMatches = count
                self.currentMatch = count > 0 ? 1 : 0
            }
        }
    }
}

private extension String {

    func escapedForJavaScript() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
