import Foundation
import WebKit

struct ReaderContent: Sendable {

    let title: String

    let body: String

    let textContent: String

    var isReadable: Bool {
        textContent.count > 100
    }
}

enum ReaderModeService {

    enum ExtractionError: LocalizedError {

        case webViewUnavailable

        case invalidResponse

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

    static func extractContent(from webView: WKWebView) async -> ReaderContent? {
        do {
            return try await performExtraction(from: webView)
        } catch {
            return nil
        }
    }

    static func extractContentThrowing(from webView: WKWebView) async throws -> ReaderContent {
        try await performExtraction(from: webView)
    }

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
