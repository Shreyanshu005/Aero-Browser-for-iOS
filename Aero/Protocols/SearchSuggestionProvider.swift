//
//  SearchSuggestionProvider.swift
//  Aero
//
//  Created on 2026-05-27.
//

import Foundation

/// Protocol for services that provide search query autocompletion suggestions.
///
/// Conforming types fetch suggestions from an external source (e.g., Google, DuckDuckGo)
/// given a partial query string. The protocol uses `Result` to communicate both success
/// and failure cases explicitly without relying on thrown errors alone.
///
/// ## Example Usage
/// ```swift
/// let provider: SearchSuggestionProvider = GoogleSuggestionProvider()
/// let result = await provider.suggestions(query: "swift")
/// switch result {
/// case .success(let items):
///     print(items) // ["swift", "swiftui", "swift programming", ...]
/// case .failure(let error):
///     print("Failed: \(error)")
/// }
/// ```
protocol SearchSuggestionProvider {
    /// Fetches autocomplete suggestions for the given query.
    ///
    /// - Parameter query: The partial search query to autocomplete.
    /// - Returns: A `Result` containing an array of suggestion strings on success,
    ///   or an `Error` on failure.
    func suggestions(query: String) async -> Result<[String], Error>
}
