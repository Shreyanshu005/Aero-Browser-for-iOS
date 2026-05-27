import WebKit

enum BrowserWebViewConfigurationFactory {
    static func makeConfiguration(
        contentBlocker: ContentBlocker,
        isContentBlockerEnabled: Bool
    ) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        if isContentBlockerEnabled {
            contentBlocker.apply(to: configuration)
        }

        return configuration
    }
}
