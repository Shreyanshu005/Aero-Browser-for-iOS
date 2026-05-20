






import Foundation
import Observation

@Observable
final class HistoryStore {
    private(set) var items: [HistoryItem] = []
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("aero_history.json")
        loadFromDisk()
    }



    func addVisit(url: URL, title: String) {
        let item = HistoryItem(url: url, title: title)
        items.insert(item, at: 0)


        if items.count > 5000 {
            items = Array(items.prefix(5000))
        }

        saveToDisk()
    }

    func clearHistory() {
        items.removeAll()
        saveToDisk()
    }

    func search(query: String) -> [HistoryItem] {
        let lowered = query.lowercased()
        return items.filter { item in
            item.title.lowercased().contains(lowered) ||
            item.url.absoluteString.lowercased().contains(lowered)
        }
    }


    func groupedByDay() -> [(key: String, items: [HistoryItem])] {
        let grouped = Dictionary(grouping: items, by: { $0.dayKey })
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Today" { return true }
            if k2 == "Today" { return false }
            if k1 == "Yesterday" { return true }
            if k2 == "Yesterday" { return false }
            return k1 > k2
        }
        return sortedKeys.map { key in
            (key: key, items: grouped[key] ?? [])
        }
    }



    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save history: \(error)")
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
        } catch {
            print("[Aero] Failed to load history: \(error)")
        }
    }
}
