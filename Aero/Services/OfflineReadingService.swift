import Foundation
import Observation

/// Manages a list of web pages saved for offline reading.
@Observable
final class OfflineReadingService {

    // MARK: - Public State

    /// All items in the reading list, ordered by save date (newest first).
    private(set) var items: [ReadingListItem] = []

    // MARK: - Private

    private let fileURL: URL

    // MARK: - Init

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("aero_reading_list.json")
        loadFromDisk()
    }

    // MARK: - Public API

    /// Adds a page to the reading list.
    func addItem(title: String, url: URL, excerpt: String = "") {
        guard !items.contains(where: { $0.url == url }) else { return }

        let item = ReadingListItem(title: title, url: url, excerpt: excerpt)
        items.insert(item, at: 0)
        saveToDisk()
    }

    /// Removes a specific item from the reading list.
    func removeItem(_ item: ReadingListItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    /// Toggles the read/unread state of an item.
    func toggleRead(_ item: ReadingListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead.toggle()
        saveToDisk()
    }

    /// Removes all items from the reading list.
    func clearAll() {
        items.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save reading list: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([ReadingListItem].self, from: data)
        } catch {
            print("[Aero] Failed to load reading list: \(error)")
        }
    }
}
