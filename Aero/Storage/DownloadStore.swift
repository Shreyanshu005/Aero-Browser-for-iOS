import Foundation

struct DownloadRecord: Codable, Equatable, Identifiable {
    let id: UUID
    let url: URL
    let filename: String
    let state: DownloadState
    let progress: Double
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let localURL: URL?
    let errorMessage: String?
    let startedAt: Date
}

protocol DownloadStoring {
    func loadDownloads() -> [DownloadRecord]
    func saveDownloads(_ downloads: [DownloadRecord])
}

final class DownloadStore: DownloadStoring {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            self.fileURL = docs.appendingPathComponent("aero_downloads.json")
        }
    }

    func loadDownloads() -> [DownloadRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DownloadRecord].self, from: data)
        } catch {
            print("[Aero] Failed to load downloads: \(error)")
            return []
        }
    }

    func saveDownloads(_ downloads: [DownloadRecord]) {
        do {
            let data = try JSONEncoder().encode(downloads)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Aero] Failed to save downloads: \(error)")
        }
    }
}
