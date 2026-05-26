import Foundation
import Observation

struct PendingDownload: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let suggestedFilename: String?
    let sourceHost: String
    let mimeType: String?
    let expectedByteCount: Int64?

    var displayFilename: String {
        DownloadFilenameResolver.safeFilename(suggestedFilename: suggestedFilename, fallbackURL: url)
    }

    var formattedSize: String? {
        guard let expectedByteCount, expectedByteCount > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: expectedByteCount, countStyle: .file)
    }
}

struct DownloadFilenameResolver {
    static func safeFilename(suggestedFilename: String?, fallbackURL: URL) -> String {
        let rawFilename = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackFilename = fallbackURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = [rawFilename, fallbackFilename]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? "download"

        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:").union(.controlCharacters)
        let sanitized = filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        return sanitized.isEmpty ? "download" : String(sanitized.prefix(160))
    }

    static func uniqueFilename(
        _ filename: String,
        in directory: URL,
        existingFilenames: Set<String> = []
    ) -> String {
        let fileManager = FileManager.default
        let nsFilename = filename as NSString
        let baseName = nsFilename.deletingPathExtension.isEmpty ? filename : nsFilename.deletingPathExtension
        let pathExtension = nsFilename.pathExtension

        var candidate = filename
        var suffix = 2

        while existingFilenames.contains(candidate) ||
                fileManager.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = pathExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(pathExtension)"
            suffix += 1
        }

        return candidate
    }
}

@Observable
final class DownloadManager: NSObject {
    var downloads: [DownloadItem] = []
    private var activeTasks: [URLSessionDownloadTask: UUID] = [:]

    @ObservationIgnored
    private let store: DownloadStoring

    @ObservationIgnored
    private let downloadsDirectoryURL: URL

    @ObservationIgnored
    private var session: URLSession!

    init(
        store: DownloadStoring = DownloadStore(),
        downloadsDirectoryURL: URL? = nil
    ) {
        self.store = store
        if let downloadsDirectoryURL {
            self.downloadsDirectoryURL = downloadsDirectoryURL
        } else {
            self.downloadsDirectoryURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("Downloads", isDirectory: true)
        }

        super.init()

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        downloads = restoredDownloads(from: store.loadDownloads())
    }

    func startDownload(url: URL, suggestedFilename: String? = nil) {
        try? FileManager.default.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true)

        let safeFilename = DownloadFilenameResolver.safeFilename(
            suggestedFilename: suggestedFilename,
            fallbackURL: url
        )
        let filename = DownloadFilenameResolver.uniqueFilename(
            safeFilename,
            in: downloadsDirectoryURL,
            existingFilenames: Set(downloads.map(\.filename))
        )
        let item = DownloadItem(url: url, filename: filename)
        item.state = .downloading
        downloads.insert(item, at: 0)

        let task = session.downloadTask(with: url)
        activeTasks[task] = item.id
        task.resume()
        saveDownloadHistory()
    }

    func cancelDownload(id: UUID) {
        if let entry = activeTasks.first(where: { $0.value == id }) {
            entry.key.cancel()
            activeTasks.removeValue(forKey: entry.key)
        }
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            downloads[index].state = .cancelled
            downloads[index].progress = 0
            saveDownloadHistory()
        }
    }

    func retryDownload(id: UUID) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        guard downloads[index].state == .failed || downloads[index].state == .cancelled else { return }

        downloads[index].state = .downloading
        downloads[index].progress = 0
        downloads[index].bytesDownloaded = 0
        downloads[index].totalBytes = 0
        downloads[index].errorMessage = nil

        let task = session.downloadTask(with: downloads[index].url)
        activeTasks[task] = downloads[index].id
        task.resume()
        saveDownloadHistory()
    }

    func removeDownload(id: UUID) {
        downloads.removeAll { $0.id == id }
        saveDownloadHistory()
    }

    func deleteDownload(id: UUID) {
        guard let item = downloads.first(where: { $0.id == id }) else { return }
        if let localURL = item.localURL {
            try? FileManager.default.removeItem(at: localURL)
        }
        removeDownload(id: id)
    }

    func clearCompleted() {
        downloads.removeAll { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }
        saveDownloadHistory()
    }

    private func destinationURL(for item: DownloadItem) -> URL {
        downloadsDirectoryURL.appendingPathComponent(item.filename)
    }

    private func restoredDownloads(from records: [DownloadRecord]) -> [DownloadItem] {
        records.compactMap { record in
            if record.state == .completed {
                guard let localURL = record.localURL,
                      FileManager.default.fileExists(atPath: localURL.path) else {
                    return nil
                }
            }
            return DownloadItem(record: record)
        }
    }

    private func saveDownloadHistory() {
        let records = downloads
            .filter { $0.state != .downloading && $0.state != .pending }
            .map { $0.record }
        store.saveDownloads(records)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = activeTasks[downloadTask] else { return }
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        try? FileManager.default.createDirectory(at: downloadsDirectoryURL, withIntermediateDirectories: true)

        let destination = destinationURL(for: downloads[index])
        try? FileManager.default.removeItem(at: destination)

        do {
            try FileManager.default.moveItem(at: location, to: destination)
            downloads[index].localURL = destination
            downloads[index].state = .completed
            downloads[index].progress = 1.0
            downloads[index].errorMessage = nil
        } catch {
            downloads[index].state = .failed
            downloads[index].errorMessage = error.localizedDescription
        }

        activeTasks.removeValue(forKey: downloadTask)
        saveDownloadHistory()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
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
                saveDownloadHistory()
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

    init(
        id: UUID = UUID(),
        url: URL,
        filename: String,
        state: DownloadState = .pending,
        progress: Double = 0,
        bytesDownloaded: Int64 = 0,
        totalBytes: Int64 = 0,
        localURL: URL? = nil,
        errorMessage: String? = nil,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.filename = filename
        self.state = state
        self.progress = progress
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.localURL = localURL
        self.errorMessage = errorMessage
        self.startedAt = startedAt
    }

    convenience init(record: DownloadRecord) {
        self.init(
            id: record.id,
            url: record.url,
            filename: record.filename,
            state: record.state,
            progress: record.progress,
            bytesDownloaded: record.bytesDownloaded,
            totalBytes: record.totalBytes,
            localURL: record.localURL,
            errorMessage: record.errorMessage,
            startedAt: record.startedAt
        )
    }

    var record: DownloadRecord {
        DownloadRecord(
            id: id,
            url: url,
            filename: filename,
            state: state,
            progress: progress,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
            localURL: localURL,
            errorMessage: errorMessage,
            startedAt: startedAt
        )
    }

    var formattedProgress: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
        if totalBytes > 0 {
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
        return downloaded
    }

    var isFileAvailable: Bool {
        guard state == .completed, let localURL else { return false }
        return FileManager.default.fileExists(atPath: localURL.path)
    }
}

enum DownloadState: String, Codable, Equatable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
}
