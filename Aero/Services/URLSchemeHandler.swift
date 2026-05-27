import Foundation
import Observation

enum URLSchemeAction {
    case openURL(URL)
    case search(String)
    case openSettings
    case newTab
}

@Observable
final class URLSchemeHandler {
    func handle(url: URL) -> URLSchemeAction? {
        guard url.scheme == "aero" else { return nil }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        
        switch url.host {
        case "open":
            if let queryItem = components.queryItems?.first(where: { $0.name == "url" }),
               let urlString = queryItem.value,
               let targetURL = URL(string: urlString) {
                return .openURL(targetURL)
            }
        case "search":
            if let queryItem = components.queryItems?.first(where: { $0.name == "q" }),
               let query = queryItem.value {
                return .search(query)
            }
        case "settings":
            return .openSettings
        case "newtab":
            return .newTab
        default:
            return nil
        }
        
        return nil
    }
}
