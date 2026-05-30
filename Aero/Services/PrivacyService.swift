import Foundation
import WebKit

enum PrivacyService {

    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"

    @MainActor
    static func clearAllWebsiteData() async {
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: allTypes)
        await dataStore.removeData(ofTypes: allTypes, for: records)
    }

    @MainActor
    static func clearCookies() async {
        let dataStore = WKWebsiteDataStore.default()
        let cookieTypes: Set<String> = [WKWebsiteDataTypeCookies]
        let records = await dataStore.dataRecords(ofTypes: cookieTypes)
        await dataStore.removeData(ofTypes: cookieTypes, for: records)
    }

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

    @MainActor
    static func clearHistory(using store: HistoryStore) {
        store.clearHistory()
    }

    static func setDesktopUserAgent(on webView: WKWebView) {
        webView.customUserAgent = desktopUserAgent
    }

    static func resetUserAgent(on webView: WKWebView) {
        webView.customUserAgent = nil
    }

    static func isDesktopUserAgentActive(on webView: WKWebView) -> Bool {
        webView.customUserAgent == desktopUserAgent
    }
}

private extension WKWebsiteDataStore {

    func dataRecords(ofTypes types: Set<String>) async -> [WKWebsiteDataRecord] {
        await withCheckedContinuation { continuation in
            fetchDataRecords(ofTypes: types) { records in
                continuation.resume(returning: records)
            }
        }
    }

    func removeData(ofTypes types: Set<String>, for records: [WKWebsiteDataRecord]) async {
        await withCheckedContinuation { continuation in
            removeData(ofTypes: types, for: records) {
                continuation.resume()
            }
        }
    }
}
