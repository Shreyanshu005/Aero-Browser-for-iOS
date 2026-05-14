import Foundation

struct WikiSuggestion: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let summary: String
    let pageURL: URL?
}
