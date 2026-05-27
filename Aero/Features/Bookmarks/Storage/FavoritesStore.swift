import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "FavoritesStore")

@Model
final class FavoriteItem: Identifiable, Hashable {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: URL

    init(title: String, url: URL) {
        self.id = UUID()
        self.title = title
        self.url = url
    }

    var displayInitial: String {
        String(title.prefix(1)).uppercased()
    }
}

@Observable
final class FavoritesStore {
    private let context: ModelContext

    @MainActor
    init() {
        self.context = StorageProvider.shared.container.mainContext
        
        let fetchDescriptor = FetchDescriptor<FavoriteItem>()
        if let count = try? context.fetchCount(fetchDescriptor), count == 0 {
            seedDefaults()
        }
    }

    @MainActor
    func add(title: String, url: URL) {
        let item = FavoriteItem(title: title, url: url)
        context.insert(item)
        try? context.save()
    }

    @MainActor
    func remove(id: UUID) {
        let fetchDescriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.id == id })
        if let items = try? context.fetch(fetchDescriptor), let item = items.first {
            context.delete(item)
            try? context.save()
        }
    }

    @MainActor
    private func seedDefaults() {
        let defaults: [(String, String)] = [
            ("Google",   "https://www.google.com"),
            ("YouTube",  "https://www.youtube.com"),
            ("GitHub",   "https://github.com"),
            ("Reddit",   "https://www.reddit.com"),
            ("Twitter",  "https://x.com"),
            ("Wikipedia","https://en.wikipedia.org"),
        ]

        for (title, urlString) in defaults {
            if let url = URL(string: urlString) {
                let item = FavoriteItem(title: title, url: url)
                context.insert(item)
            }
        }
        try? context.save()
    }
}
