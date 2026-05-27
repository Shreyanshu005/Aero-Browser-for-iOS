import SwiftUI
import WebKit

@Observable
final class Tab: Identifiable {
    let id: UUID
    let browsingMode: BrowsingMode
    var url: URL? {
        didSet {
            if let serverCertificateSummary,
               (!serverCertificateSummary.matches(host: url?.host) || url?.scheme?.lowercased() != "https") {
                self.serverCertificateSummary = nil
            }
            refreshSecuritySummary()
        }
    }
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
    var securitySummary: SecuritySummary = SecuritySummary(url: nil)
    var siteStatus: SiteStatus
    var snapshot: UIImage?
    var favicon: UIImage?
    var pageBackgroundColor: UIColor = .systemBackground
    let createdAt: Date
    var lastAccessedAt: Date
    private var serverCertificateSummary: CertificateSummary? {
        didSet {
            refreshSecuritySummary()
        }
    }

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
        let isSecure = url?.isSecure ?? false
        self.isSecure = isSecure
        self.siteStatus = SiteStatus(url: url, isSecureConnection: isSecure)
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        refreshSecuritySummary()
    }

    func updatePageStatus(url: URL?, isSecure: Bool) {
        self.url = url
        self.isSecure = isSecure

        var status = siteStatus
        status.updatePage(url: url, isSecureConnection: isSecure)
        siteStatus = status
    }

    func updateContentBlockerStatus(isEnabled: Bool) {
        var status = siteStatus
        status.updateContentBlocker(isEnabled: isEnabled)
        siteStatus = status
    }

    func recordMediaCaptureRequest(_ type: SiteMediaCaptureType) {
        var status = siteStatus
        status.recordMediaCaptureRequest(type)
        siteStatus = status
    }

    func recordPopupAttempt() {
        var status = siteStatus
        status.recordPopupAttempt()
        siteStatus = status
    }

    func updateServerCertificateSummary(_ summary: CertificateSummary?) {
        guard let summary else {
            serverCertificateSummary = nil
            return
        }

        guard summary.matches(host: url?.host) else { return }
        serverCertificateSummary = summary
    }


    private func refreshSecuritySummary() {
        let summary = SecuritySummary(url: url, certificateSummary: serverCertificateSummary)
        securitySummary = summary
        isSecure = summary.isSecure
    }


    func createWebView(
        contentBlocker: ContentBlocker = ContentBlocker(),
        isContentBlockerEnabled: Bool = false
    ) -> WKWebView {
        if let existing = webView {
            return existing
        }

        let config = BrowserWebViewConfigurationFactory.makeConfiguration(
            contentBlocker: contentBlocker,
            isContentBlockerEnabled: isContentBlockerEnabled,
            browsingMode: browsingMode
        )

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.alwaysBounceVertical = true

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
