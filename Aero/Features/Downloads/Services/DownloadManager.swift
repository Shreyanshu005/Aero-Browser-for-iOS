import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.aero.browser", category: "DownloadManager")

@Observable
final class DownloadManager: NSObject {
    var downloads: [DownloadItem] = []
    private var activeTasks: [URLSessionDownloadTask: UUID] = [:]
    private var reverseTaskMap: [UUID: URLSessionDownloadTask] = [:]
    private var activeWebKitDownloads: [UUID: URL] = [:]

    var activeToast: DownloadToast? = nil

    @ObservationIgnored
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    deinit {
        session.invalidateAndCancel()
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
        reverseTaskMap[item.id] = task
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
        if let task = reverseTaskMap[id] {
            task.cancel()
            activeTasks.removeValue(forKey: task)
            reverseTaskMap.removeValue(forKey: id)
        }
        if let index = downloads.firstIndex(where: { $0.id == id }) {
            downloads[index].state = .cancelled
        }
    }

    func retryDownload(id: UUID) {
        guard let item = downloads.first(where: { $0.id == id }) else { return }
        removeDownload(id: id)
        startDownload(url: item.url, suggestedFilename: item.filename)
    }

    func removeDownload(id: UUID) {
        downloads.removeAll { $0.id == id }
    }

    func clearCompleted() {
        downloads.removeAll { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }
    }

    func documentsDirectory() -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Documents directory unavailable, falling back to tmp")
            return URL(fileURLWithPath: NSTemporaryDirectory())
        }
        return docs.appendingPathComponent("Downloads", isDirectory: true)
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = activeTasks[downloadTask] else { return }
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }

        let downloadsDir = documentsDirectory()

        do {
            try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create downloads directory: \(error.localizedDescription)")
            downloads[index].state = .failed
            downloads[index].errorMessage = "Could not create downloads folder"
            return
        }

        let destination = downloadsDir.appendingPathComponent(downloads[index].filename)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            logger.error("Failed to move downloaded file: \(error.localizedDescription)")
            downloads[index].state = .failed
            downloads[index].errorMessage = "Failed to save file: \(error.localizedDescription)"
            return
        }

        downloads[index].localURL = destination
        downloads[index].state = .completed
        downloads[index].progress = 1.0
        activeTasks.removeValue(forKey: downloadTask)
        reverseTaskMap.removeValue(forKey: id)
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
        reverseTaskMap.removeValue(forKey: id)
    }
}
