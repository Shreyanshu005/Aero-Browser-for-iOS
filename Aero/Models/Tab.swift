import SwiftUI
import WebKit

@Observable
final class Tab: Identifiable {
    let id: UUID
    var url: URL?
    var title: String
    var displayTitle: String {
        if title.isEmpty {
            return url?.displayHost ?? "New Tab"
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
    var pageBackgroundColor: UIColor = .systemBackground
    let createdAt: Date
    var lastAccessedAt: Date

    var webView: WKWebView?

    init(url: URL? = nil) {
        self.id = UUID()
        self.url = url
        self.title = ""
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }

    func createWebView() -> WKWebView {
        if let existing = webView {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.alwaysBounceVertical = true

        self.webView = wv
        return wv
    }

    // ← Fixed: no snapshotWidth cap, full resolution
    func captureSnapshot() {
        guard let webView = webView else { return }
        let config = WKSnapshotConfiguration()
        // removed snapshotWidth — was forcing tiny 200pt image

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
