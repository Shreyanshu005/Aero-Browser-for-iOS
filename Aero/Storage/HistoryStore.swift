import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "HistoryStore")

@Observable
final class HistoryStore {
    private(set) var items: [HistoryItem] = []
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var cachedGroups: [(key: String, items: [HistoryItem])]?

    init() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Failed to locate documents directory")
            self.fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("aero_history.json")
            return
        }
        self.fileURL = docs.appendingPathComponent("aero_history.json")
        loadFromDisk()
    }

    func addVisit(url: URL, title: String) {
        let item = HistoryItem(url: url, title: title)
        items.insert(item, at: 0)

        if items.count > 5000 {
            items = Array(items.prefix(5000))
        }

        invalidateGroupCache()
        debouncedSave()
    }

    func clearHistory() {
        items.removeAll()
        invalidateGroupCache()
        debouncedSave()
    }

    func search(query: String) -> [HistoryItem] {
        let lowered = query.lowercased()
        return items.filter { item in
            item.title.lowercased().contains(lowered) ||
            item.url.absoluteString.lowercased().contains(lowered)
        }
    }

    func groupedByDay() -> [(key: String, items: [HistoryItem])] {
        if let cached = cachedGroups {
            return cached
        }

        let grouped = Dictionary(grouping: items, by: { $0.dayKey })
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Today" { return true }
            if k2 == "Today" { return false }
            if k1 == "Yesterday" { return true }
            if k2 == "Yesterday" { return false }
            return k1 > k2
        }
        let result = sortedKeys.map { key in
            (key: key, items: grouped[key] ?? [])
        }
        cachedGroups = result
        return result
    }

    // MARK: - Private

    private func invalidateGroupCache() {
        cachedGroups = nil
    }

    /// Debounced save: coalesces rapid mutations into a single disk write after 1 second of inactivity.
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            guard !Task.isCancelled else { return }
            await self?.performSave()
        }
    }

    @MainActor
    private func performSave() {
        let itemsCopy = items
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(itemsCopy)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                logger.error("Failed to save history: \(error.localizedDescription)")
            }
        }
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([HistoryItem].self, from: data)
            invalidateGroupCache()
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
        }
    }
}
