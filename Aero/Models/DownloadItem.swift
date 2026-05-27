import Foundation
import Observation

@Observable
final class DownloadItem: Identifiable {

    let id: UUID

    let url: URL

    var filename: String

    var state: DownloadState = .pending

    var progress: Double = 0.0

    var bytesDownloaded: Int64 = 0

    var totalBytes: Int64 = 0

    var localURL: URL?

    var errorMessage: String?

    let startedAt: Date

    init(url: URL, filename: String) {
        self.id = UUID()
        self.url = url
        self.filename = filename
        self.startedAt = Date()
    }

    var formattedProgress: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
        if totalBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
        return downloaded
    }
}

enum DownloadState: Equatable {

    case pending

    case downloading

    case completed

    case failed

    case cancelled
}

struct DownloadToast: Identifiable, Equatable {

    let id = UUID()

    let filename: String
}
