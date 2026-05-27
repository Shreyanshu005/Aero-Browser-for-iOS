import Foundation

@MainActor
enum TabDeduplicationService {
    static func findDuplicate(url: URL, in tabs: [Tab], excluding tabID: UUID? = nil) -> Tab? {
        let normalizedTarget = normalizeURL(url)
        return tabs.first { tab in
            guard tab.id != tabID else { return false }
            guard let tabURL = tab.url else { return false }
            return normalizeURL(tabURL) == normalizedTarget
        }
    }
    
    static func normalizeURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        
        components.fragment = nil
        
        if let queryItems = components.queryItems {
            let trackingParams = [
                "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
                "ref", "fbclid", "gclid", "msclkid"
            ]
            let filtered = queryItems.filter { !trackingParams.contains($0.name.lowercased()) }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }
        
        if components.path.hasSuffix("/") && components.path.count > 1 {
            components.path.removeLast()
        }
        
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        
        return components.url ?? url
    }
}
