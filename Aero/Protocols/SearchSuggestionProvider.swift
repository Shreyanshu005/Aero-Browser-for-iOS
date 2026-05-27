import Foundation

protocol SearchSuggestionProvider {

    func suggestions(query: String) async -> Result<[String], Error>
}
