import Foundation
import WebKit

/// Centralized service for privacy-related operations.
///
/// This consolidates data-clearing logic that was previously duplicated across
/// `MenuSheet`, `SettingsView`, and other locations, providing a single source of
/// truth for privacy operations.
enum PrivacyService {

    // MARK: - User Agent Constants

    /// The desktop Safari user agent string used when requesting desktop sites.
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    // MARK: - Data Clearing

    /// Clears all website data from the default `WKWebsiteDataStore`.
    ///
    /// This removes cookies, caches, local storage, IndexedDB, service workers,
    /// and all other data types tracked by WebKit.
    @MainActor
    static func clearAllWebsiteData() async {
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: allTypes)
        await dataStore.removeData(ofTypes: allTypes, for: records)
    }

    /// Clears only cookies from the default `WKWebsiteDataStore`.
    @MainActor
    static func clearCookies() async {
        let dataStore = WKWebsiteDataStore.default()
        let cookieTypes: Set<String> = [WKWebsiteDataTypeCookies]
        let records = await dataStore.dataRecords(ofTypes: cookieTypes)
        await dataStore.removeData(ofTypes: cookieTypes, for: records)
    }

    /// Clears only cached data (disk and memory caches) from the default `WKWebsiteDataStore`.
    @MainActor
    static func clearCache() async {
        let dataStore = WKWebsiteDataStore.default()
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache
        ]
        let records = await dataStore.dataRecords(ofTypes: cacheTypes)
        await dataStore.removeData(ofTypes: cacheTypes, for: records)
    }

    /// Clears the browsing history using the provided history store.
    ///
    /// - Parameter store: The `HistoryStore` instance whose history should be cleared.
    @MainActor
    static func clearHistory(using store: HistoryStore) {
        store.clearHistory()
    }

    // MARK: - User Agent Management

    /// Sets the desktop user agent on the given web view, causing subsequent page loads
    /// to request desktop versions of websites.
    ///
    /// - Parameter webView: The `WKWebView` to configure.
    static func setDesktopUserAgent(on webView: WKWebView) {
        webView.customUserAgent = desktopUserAgent
    }

    /// Resets the user agent to the default value by removing the custom user agent string.
    ///
    /// - Parameter webView: The `WKWebView` to reset.
    static func resetUserAgent(on webView: WKWebView) {
        webView.customUserAgent = nil
    }

    /// Returns whether the given web view is currently configured to use the desktop user agent.
    ///
    /// - Parameter webView: The `WKWebView` to check.
    /// - Returns: `true` if the desktop user agent is active.
    static func isDesktopUserAgentActive(on webView: WKWebView) -> Bool {
        webView.customUserAgent == desktopUserAgent
    }
}

// MARK: - WKWebsiteDataStore Extension

private extension WKWebsiteDataStore {
    /// Async wrapper around `fetchDataRecords(ofTypes:completionHandler:)`.
    func dataRecords(ofTypes types: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: types) { records in
                continuation.resume(returning: records)
            }
        }
    }

    /// Async wrapper around `removeData(ofTypes:for:completionHandler:)`.
    func removeData(ofTypes types: Set<String>, for records: [WKWebsiteDataRecord]) async {
        await withCheckedContinuation { continuation in
            removeData(ofTypes: types, for: records) {
                continuation.resume()
            }
        }
    }
}
