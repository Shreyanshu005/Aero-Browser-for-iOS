//
//  ReaderModeService.swift
//  Aero
//
//  Created on 2026-05-27.
//

import Foundation
import WebKit

// MARK: - ReaderContent Model

/// Structured content extracted from a web page for reader mode display.
struct ReaderContent: Sendable {
    /// The page title, typically from `document.title`.
    let title: String

    /// The main content as cleaned HTML, suitable for rendering in a web view or attributed text.
    let body: String

    /// The plain text representation of the main content, with HTML tags stripped.
    let textContent: String

    /// Whether the extracted content appears to have meaningful readable text.
    var isReadable: Bool {
        textContent.count > 100
    }
}

// MARK: - ReaderModeService

/// Service responsible for extracting readable content from web pages.
///
/// This moves the JavaScript content-extraction logic out of `ReaderModeView` into a
/// reusable service. It attempts to find the best content container on the page
/// (`<article>`, `<main>`, or falling back to `<p>` extraction from `<body>`),
/// then returns both raw HTML and cleaned plain text.
enum ReaderModeService {

    // MARK: - Errors

    /// Errors that can occur during content extraction.
    enum ExtractionError: LocalizedError {
        /// The web view was nil or deallocated.
        case webViewUnavailable
        /// JavaScript evaluation returned an unexpected format.
        case invalidResponse
        /// The page did not contain enough readable content.
        case noReadableContent

        var errorDescription: String? {
            switch self {
            case .webViewUnavailable:
                return "The web view is no longer available."
            case .invalidResponse:
                return "Failed to parse the page content."
            case .noReadableContent:
                return "This page doesn't have readable content."
            }
        }
    }

    // MARK: - Public API

    /// Extracts readable content from the given web view's currently loaded page.
    ///
    /// - Parameter webView: The `WKWebView` containing the page to extract content from.
    /// - Returns: A `ReaderContent` instance with the extracted title and content,
    ///   or `nil` if extraction fails or the page has insufficient readable content.
    static func extractContent(from webView: WKWebView) async -> ReaderContent? {
        do {
            return try await performExtraction(from: webView)
        } catch {
            return nil
        }
    }

    /// Extracts readable content with full error information.
    ///
    /// - Parameter webView: The `WKWebView` containing the page to extract content from.
    /// - Returns: A `ReaderContent` instance.
    /// - Throws: `ExtractionError` if extraction fails.
    static func extractContentThrowing(from webView: WKWebView) async throws -> ReaderContent {
        try await performExtraction(from: webView)
    }

    // MARK: - Private Implementation

    /// The JavaScript that extracts readable content from the DOM.
    ///
    /// Strategy:
    /// 1. Try `<article>` element first (most semantically correct).
    /// 2. Fall back to `<main>` or `<body>`.
    /// 3. Collect `<p>` elements with > 40 chars as meaningful paragraphs.
    /// 4. Return both HTML and plain text for flexibility.
    private static let extractionScript = """
    (function() {
        var title = document.title || '';
        var content = '';
        var htmlContent = '';
        
        var article = document.querySelector('article');
        if (article) {
            content = article.innerText;
            htmlContent = article.innerHTML;
        } else {
            var main = document.querySelector('main') || document.querySelector('[role="main"]') || document.body;
            var paragraphs = main.querySelectorAll('p');
            var texts = [];
            var htmlParts = [];
            for (var i = 0; i < paragraphs.length; i++) {
                var text = paragraphs[i].innerText.trim();
                if (text.length > 40) {
                    texts.push(text);
                    htmlParts.push('<p>' + paragraphs[i].innerHTML + '</p>');
                }
            }
            content = texts.join('\\n\\n');
            htmlContent = htmlParts.join('\\n');
        }
        
        return JSON.stringify({
            title: title,
            content: content,
            htmlContent: htmlContent
        });
    })()
    """

    private static func performExtraction(from webView: WKWebView) async throws -> ReaderContent {
        let result: Any?
        do {
            result = try await webView.evaluateJavaScript(extractionScript)
        } catch {
            throw ExtractionError.invalidResponse
        }

        guard let jsonString = result as? String,
              let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            throw ExtractionError.invalidResponse
        }

        let title = parsed["title"] ?? ""
        let textContent = parsed["content"] ?? ""
        let htmlContent = parsed["htmlContent"] ?? ""

        let readerContent = ReaderContent(
            title: title,
            body: htmlContent,
            textContent: textContent
        )

        guard readerContent.isReadable else {
            throw ExtractionError.noReadableContent
        }

        return readerContent
    }
}
