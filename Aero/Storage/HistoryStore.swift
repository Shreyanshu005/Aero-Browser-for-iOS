import Foundation
import SwiftData
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "HistoryStore")

@Observable
final class HistoryStore {
    private let context: ModelContext

    @MainActor
    init() {
        self.context = StorageProvider.shared.container.mainContext
    }

    @MainActor
    func addVisit(url: URL, title: String) {
        let item = HistoryItem(url: url, title: title)
        context.insert(item)
        try? context.save()
        
        let fetchDescriptor = FetchDescriptor<HistoryItem>()
        if let count = try? context.fetchCount(fetchDescriptor), count > 5000 {
            var oldestFetch = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.visitDate, order: .forward)])
            oldestFetch.fetchLimit = count - 5000
            if let oldest = try? context.fetch(oldestFetch) {
                for item in oldest {
                    context.delete(item)
                }
                try? context.save()
            }
        }
    }

    @MainActor
    func clearHistory() {
        try? context.delete(model: HistoryItem.self)
        try? context.save()
    }
}
