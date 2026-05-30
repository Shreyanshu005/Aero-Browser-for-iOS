import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "TabStatePersistence")

struct PersistedTab: Codable, Identifiable {
    let id: UUID
    let urlString: String?
    let title: String?
    let lastAccessedAt: Date
}

@Observable
@MainActor
final class TabStatePersistence {
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            self.fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tab_state.json")
            return
        }
        self.fileURL = docs.appendingPathComponent("tab_state.json")
    }

    func saveTabs(_ tabs: [Tab], activeIndex: Int) {
        let persistedTabs = tabs.map { tab in
            PersistedTab(
                id: tab.id,
                urlString: tab.url?.absoluteString,
                title: tab.title,
                lastAccessedAt: tab.lastAccessedAt
            )
        }

        let state = PersistedState(tabs: persistedTabs, activeIndex: activeIndex)
        debouncedSave(state: state)
    }

    func loadTabs() -> (tabs: [PersistedTab], activeIndex: Int)? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            return (state.tabs, state.activeIndex)
        } catch {
            logger.error("Failed to load tab state: \(error.localizedDescription)")
            return nil
        }
    }

    private func debouncedSave(state: PersistedState) {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) 
            guard !Task.isCancelled else { return }
            await self?.performSave(state: state)
        }
    }

    private func performSave(state: PersistedState) async {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: self.fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save tab state: \(error.localizedDescription)")
        }
    }
}

private struct PersistedState: Codable {
    let tabs: [PersistedTab]
    let activeIndex: Int
}
