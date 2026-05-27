import WebKit

enum BrowserWebViewConfigurationFactory {
    static func makeConfiguration(
        contentBlocker: ContentBlocker,
        isContentBlockerEnabled: Bool,
        browsingMode: BrowsingMode = .standard
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        if browsingMode == .privateBrowsing {
            configuration.websiteDataStore = .nonPersistent()
        }
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        if isContentBlockerEnabled {
            contentBlocker.apply(to: configuration)
        }

        return configuration
    }
}
