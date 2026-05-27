






import SwiftUI
import WebKit

@Observable
final class Tab: Identifiable {
    let id: UUID
    var url: URL?
    var title: String
    var navigationError: BrowserError?

    var displayURL: URL? {
        navigationError?.url ?? url
    }

    var displayTitle: String {
        if title.isEmpty {
            return displayURL?.displayHost ?? "New Tab"
        }
        return title
    }
    var isLoading: Bool = false
    var estimatedProgress: Double = 0.0
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isSecure: Bool = false
    var snapshot: UIImage?
    var favicon: UIImage?
    let createdAt: Date
    var lastAccessedAt: Date



    var webView: WKWebView?

    init(
        url: URL? = nil,
        title: String = "",
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }


    func createWebView(
        contentBlocker: ContentBlocker,
        isContentBlockerEnabled: Bool
    ) -> WKWebView {
        if let existing = webView {
            return existing
        }

        let config = BrowserWebViewConfigurationFactory.makeConfiguration(
            contentBlocker: contentBlocker,
            isContentBlockerEnabled: isContentBlockerEnabled
        )

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        self.webView = wv
        return wv
    }

    func discardWebView() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
        webView?.scrollView.delegate = nil
        webView = nil
        isLoading = false
        estimatedProgress = 0.0
        canGoBack = false
        canGoForward = false
    }


    func captureSnapshot() {
        guard let webView = webView else { return }
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 200

        webView.takeSnapshot(with: config) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.snapshot = image
            }
        }
    }
}

extension Tab: Equatable {
    static func == (lhs: Tab, rhs: Tab) -> Bool {
        lhs.id == rhs.id
    }
}

extension Tab: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
