






import Foundation
import Observation

@Observable
final class DownloadManager: NSObject {
    var downloads: [DownloadItem] = []
    private var activeTasks: [URLSessionDownloadTask: UUID] = [:]
    private var activeWebKitDownloads: [UUID: URL] = [:]

    var activeToast: DownloadToast? = nil

    @ObservationIgnored
    private var session: URLSession!

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    func startDownload(url: URL, suggestedFilename: String? = nil) {
        let item = DownloadItem(
            url: url,
            filename: suggestedFilename ?? url.lastPathComponent
        )
        downloads.insert(item, at: 0)
        showToast(filename: item.filename)

        let task = session.downloadTask(with: url)
        activeTasks[task] = item.id
        task.resume()
    }

    func startWebKitDownload(sourceURL: URL, filename: String) -> UUID {
        let item = DownloadItem(url: sourceURL, filename: filename)
        item.state = .downloading
        downloads.insert(item, at: 0)
        activeWebKitDownloads[item.id] = sourceURL
        showToast(filename: item.filename)
        return item.id
    }

    func updateWebKitDownloadProgress(id: UUID, progress: Double) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].progress = progress
        downloads[index].state = .downloading
    }

    func completeWebKitDownload(id: UUID, localURL: URL) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].localURL = localURL
        downloads[index].state = .completed
        downloads[index].progress = 1.0
        activeWebKitDownloads.removeValue(forKey: id)
    }

    func failWebKitDownload(id: UUID, error: Error) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        downloads[index].state = .failed
        downloads[index].errorMessage = error.localizedDescription
        activeWebKitDownloads.removeValue(forKey: id)
    }

    private func showToast(filename: String) {
        let toast = DownloadToast(filename: filename)
        activeToast = toast

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.activeToast?.id == toast.id {
                self.activeToast = nil
            }
        }
    }

    func cancelDownload(id: UUID) {
        if let entry = activeTasks.first(where: { $0.value == id }) {
            entry.key.cancel()
            activeTasks.removeValue(forKey: entry.key)
        }
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            downloads[index].state = .cancelled
        }
    }

    func removeDownload(id: UUID) {
        downloads.removeAll { $0.id == id }
    }

    func clearCompleted() {
        downloads.removeAll { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }
    }

    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
    }
}

struct DownloadToast: Identifiable, Equatable {
    let id = UUID()
    let filename: String
}



extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = activeTasks[downloadTask] else { return }
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        let downloadsDir = documentsDirectory()
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        let destination = downloadsDir.appendingPathComponent(downloads[index].filename)
        try? FileManager.default.removeItem(at: destination)
        try? FileManager.default.moveItem(at: location, to: destination)

        downloads[index].localURL = destination
        downloads[index].state = .completed
        downloads[index].progress = 1.0
        activeTasks.removeValue(forKey: downloadTask)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let id = activeTasks[downloadTask] else { return }
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        if totalBytesExpectedToWrite > 0 {
            downloads[index].progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
        downloads[index].bytesDownloaded = totalBytesWritten
        downloads[index].totalBytes = totalBytesExpectedToWrite
        downloads[index].state = .downloading
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let id = activeTasks[downloadTask] else { return }

        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            if let index = downloads.firstIndex(where: { $0.id == id }) {
                downloads[index].state = .failed
                downloads[index].errorMessage = error.localizedDescription
            }
        }
        activeTasks.removeValue(forKey: downloadTask)
    }
}



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
