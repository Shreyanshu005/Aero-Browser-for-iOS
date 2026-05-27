






import SwiftUI
import WebKit

@Observable
final class Tab: Identifiable {
    let id: UUID
    let browsingMode: BrowsingMode
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
    let createdAt: Date
    var lastAccessedAt: Date

    var isPrivate: Bool {
        browsingMode == .privateBrowsing
    }



    var webView: WKWebView?

    init(
        url: URL? = nil,
        title: String = "",
        browsingMode: BrowsingMode = .standard,
        createdAt: Date = Date(),
        lastAccessedAt: Date = Date()
    ) {
        self.id = UUID()
        self.browsingMode = browsingMode
        self.url = url
        self.title = title
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
    }


    func createWebView() -> WKWebView {
        if let existing = webView {
            return existing
        }

        let config = WKWebViewConfiguration()
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        self.webView = wv
        return wv
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
