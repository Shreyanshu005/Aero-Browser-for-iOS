import Foundation

struct BrowserSessionState: Codable, Equatable {
    let activeTabIndex: Int
    let tabs: [RestoredTabState]
}

struct RestoredTabState: Codable, Equatable {
    let url: URL?
    let title: String
    let createdAt: Date
    let lastAccessedAt: Date
}

protocol SessionStoring {
    func loadSession() -> BrowserSessionState?
    func saveSession(_ session: BrowserSessionState)
}

final class SessionStore: SessionStoring {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("aero_session.json")
        }
    }

    func loadSession() -> BrowserSessionState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(BrowserSessionState.self, from: data)
        } catch {
            print("[Aero] Failed to load session: \(error)")
            return nil
        }
    }

    func saveSession(_ session: BrowserSessionState) {
        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save session: \(error)")
        }
    }
}
