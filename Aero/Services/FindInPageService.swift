//
//  FindInPageService.swift
//  Aero
//
//  Created on 2026-05-27.
//

import Foundation
import WebKit
import Observation

/// Service that handles find-in-page functionality by injecting JavaScript into a web view.
///
/// This extracts the search/highlight logic out of the `FindInPageBar` view so that the
/// view only needs to bind to `currentMatch` and `totalMatches` and call the service methods.
///
/// The service injects CSS for highlighting matches and uses `window.find()` for navigation
/// between results.
@Observable
final class FindInPageService {

    // MARK: - Published State

    /// The 1-based index of the currently focused match, or 0 if no match is focused.
    private(set) var currentMatch: Int = 0

    /// The total number of matches found on the page.
    private(set) var totalMatches: Int = 0

    /// The most recent search query, tracked to avoid redundant evaluations.
    private(set) var lastQuery: String = ""

    // MARK: - Dependencies

    /// The web view to execute find operations on. Uses `WKWebView` directly for
    /// compatibility with the existing `Tab.webView` pattern.
    private weak var webView: WKWebView?

    // MARK: - Constants

    /// CSS injected to visually highlight find-in-page matches.
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

    /// Unique identifier for the injected style element to prevent duplicates.
    private static let styleElementID = "aero-find-in-page-style"

    // MARK: - Initialization

    /// Creates a find-in-page service targeting the given web view.
    /// - Parameter webView: The `WKWebView` to search within.
    init(webView: WKWebView?) {
        self.webView = webView
    }

    // MARK: - Public API

    /// Searches for the next occurrence of the query on the page.
    ///
    /// On the first call with a new query, this injects highlight CSS and counts all
    /// matches. Subsequent calls with the same query advance to the next match.
    ///
    /// - Parameter query: The text to search for.
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

    /// Searches for the previous occurrence of the query on the page.
    ///
    /// - Parameter query: The text to search for.
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

        // The third parameter `true` makes `window.find` search backward.
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

    /// Clears all search highlights and resets the selection on the page.
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

    // MARK: - Private Helpers

    /// Resets the match tracking state to initial values.
    private func resetState() {
        currentMatch = 0
        totalMatches = 0
        lastQuery = ""
    }

    /// Injects the highlight CSS into the page if not already present.
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

    /// Counts the total occurrences of the query in the page's text content.
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

// MARK: - String Extension

private extension String {
    /// Escapes single quotes and backslashes for safe embedding in JavaScript string literals.
    func escapedForJavaScript() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
