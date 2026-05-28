import WebKit

struct ObservePageTool {
    private let service: PageObservationService

    init(service: PageObservationService = PageObservationService()) {
        self.service = service
    }

    @MainActor
    func observe(webView: WKWebView?) async throws -> PageObservation {
        try await service.observe(webView: webView)
    }

    @MainActor
    func callAsFunction(webView: WKWebView?) async throws -> PageObservation {
        try await observe(webView: webView)
    }
}
