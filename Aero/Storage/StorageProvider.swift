import SwiftData
import Foundation

@MainActor
final class StorageProvider {
    static let shared = StorageProvider()
    
    let container: ModelContainer
    
    private init() {
        do {
            let schema = Schema([HistoryItem.self, FavoriteItem.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
