import Foundation

enum GoogleSuggestService {
    static func suggestions(query: String) async -> [String] {
        guard let url = suggestURL(for: query) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let arr = json as? [Any],
                  arr.count >= 2,
                  let suggestions = arr[1] as? [String] else {
                return []
            }
            return Array(suggestions.prefix(8))
        } catch {
            return []
        }
    }

    private static func suggestURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://suggestqueries.google.com/complete/search")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "firefox"),
            URLQueryItem(name: "q", value: query),
        ]
        return components?.url
    }
}
