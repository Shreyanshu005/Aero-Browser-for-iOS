import Foundation
import Observation

@Observable
final class OfflineReadingService {

    private(set) var items: [ReadingListItem] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = documents.appendingPathComponent("aero_reading_list.json")
        loadFromDisk()
    }

    func addItem(title: String, url: URL, excerpt: String = "") {
        guard !items.contains(where: { $0.url == url }) else { return }

        let item = ReadingListItem(title: title, url: url, excerpt: excerpt)
        items.insert(item, at: 0)
        saveToDisk()
    }

    func removeItem(_ item: ReadingListItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    func toggleRead(_ item: ReadingListItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead.toggle()
        saveToDisk()
    }

    func clearAll() {
        items.removeAll()
        saveToDisk()
    }

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
