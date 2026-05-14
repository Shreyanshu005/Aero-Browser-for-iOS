import Foundation

enum WikipediaService {
    private struct SearchResponse: Decodable {
        let query: Query
    }

    private struct Query: Decodable {
        let search: [SearchResult]
    }

    private struct SearchResult: Decodable {
        let title: String
        let snippet: String
    }

    static func search(query: String) async -> [WikiSuggestion] {
        guard let url = searchURL(for: query) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(SearchResponse.self, from: data)
            return response.query.search.prefix(5).map { result in
                WikiSuggestion(
                    title: result.title,
                    summary: result.snippet.strippingHTML,
                    pageURL: pageURL(for: result.title)
                )
            }
        } catch {
            return []
        }
    }

    private static func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srlimit", value: "5"),
            URLQueryItem(name: "srsearch", value: query),
        ]
        return components?.url
    }

    private static func pageURL(for title: String) -> URL? {
        var components = URLComponents(string: "https://en.wikipedia.org/wiki/")
        components?.path += title.replacingOccurrences(of: " ", with: "_")
        return components?.url
    }
}

private extension String {
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#039;", with: "'")
    }
}
