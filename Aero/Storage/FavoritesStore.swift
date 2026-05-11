






import Foundation
import Observation

struct FavoriteItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: URL

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
    private(set) var favorites: [FavoriteItem] = []
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("aero_favorites.json")
        loadFromDisk()

        if favorites.isEmpty {
            seedDefaults()
        }
    }



    func add(title: String, url: URL) {
        let item = FavoriteItem(title: title, url: url)
        favorites.append(item)
        saveToDisk()
    }

    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        saveToDisk()
    }



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
                favorites.append(FavoriteItem(title: title, url: url))
            }
        }
        saveToDisk()
    }



    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(favorites)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save favorites: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            favorites = try JSONDecoder().decode([FavoriteItem].self, from: data)
        } catch {
            print("[Aero] Failed to load favorites: \(error)")
        }
    }
}
