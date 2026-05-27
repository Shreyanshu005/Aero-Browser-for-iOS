import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "FavoritesStore")

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
    private var saveTask: Task<Void, Never>?

    init() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate documents directory")
            self.fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("aero_favorites.json")
            return
        }
        self.fileURL = docs.appendingPathComponent("aero_favorites.json")
        loadFromDisk()

        if favorites.isEmpty {
            seedDefaults()
        }
    }

    func add(title: String, url: URL) {
        let item = FavoriteItem(title: title, url: url)
        favorites.append(item)
        debouncedSave()
    }

    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        debouncedSave()
    }

    // MARK: - Private

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
        debouncedSave()
    }

    /// Debounced save: coalesces rapid mutations into a single disk write.
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            guard !Task.isCancelled else { return }
            await self?.performSave()
        }
    }

    @MainActor
    private func performSave() {
        let favoritesCopy = favorites
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(favoritesCopy)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                logger.error("Failed to save favorites: \(error.localizedDescription)")
            }
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            favorites = try JSONDecoder().decode([FavoriteItem].self, from: data)
        } catch {
            logger.error("Failed to load favorites: \(error.localizedDescription)")
        }
    }
}
