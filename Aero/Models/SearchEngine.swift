import Foundation

enum SearchEngine: String, CaseIterable, Codable {
    case google     = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing       = "Bing"

    var searchURLTemplate: String {
        switch self {
        case .google:     return "https://www.google.com/search"
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .bing:       return "https://www.bing.com/search"
        }
    }

    var homepageURL: URL {
        switch self {
        case .google:     return URL(string: "https://www.google.com")!
        case .duckDuckGo: return URL(string: "https://duckduckgo.com")!
        case .bing:       return URL(string: "https://www.bing.com")!
        }
    }

    var iconName: String {
        switch self {
        case .google:     return "g.circle.fill"
        case .duckDuckGo: return "shield.fill"
        case .bing:       return "b.circle.fill"
        }
    }

    func searchURL(for query: String) -> URL? {
        guard var components = URLComponents(string: searchURLTemplate.replacingOccurrences(of: "%@", with: "")) else { return nil }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }
}

enum URLInput {
    case url(URL)
    case search(String)

    static func classify(_ input: String) -> URLInput {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .search(trimmed) }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            if let url = URL(string: trimmed), url.host != nil {
                return .url(url)
            }
        }

        if !trimmed.contains(" ") && trimmed.contains(".") {
            let withScheme = "https://\(trimmed)"
            if let url = URL(string: withScheme), url.host != nil {
                return .url(url)
            }
        }

        return .search(trimmed)
    }
}
