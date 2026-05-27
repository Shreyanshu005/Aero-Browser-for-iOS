import WebKit

final class DownloadCoordinator: NSObject, WKDownloadDelegate {
    private let downloadManager: DownloadManager
    private var downloadMap: [ObjectIdentifier: UUID] = [:]
    private var downloadProgressObservers: [ObjectIdentifier: NSKeyValueObservation] = [:]
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
        super.init()
    }
    
    @available(iOS 14.5, *)
    func attach(download: WKDownload, sourceURL: URL?) {
        download.delegate = self

        let key = ObjectIdentifier(download)
        if downloadMap[key] == nil {
            let url = sourceURL ?? URL(string: "about:blank")!
            let id = downloadManager.startWebKitDownload(
                sourceURL: url,
                filename: url.lastPathComponent.isEmpty ? "Download" : url.lastPathComponent
            )
            downloadMap[key] = id

            downloadProgressObservers[key] = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
                guard let self, let fraction = change.newValue else { return }
                guard let mappedID = self.downloadMap[key] else { return }
                self.downloadManager.updateWebKitDownloadProgress(id: mappedID, progress: fraction)
            }
        }
    }

    @available(iOS 14.5, *)
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        let destination = downloadsDir.appendingPathComponent(suggestedFilename)
        
        try? FileManager.default.removeItem(at: destination)
        downloadDestinations[ObjectIdentifier(download)] = destination
        completionHandler(destination)

        let key = ObjectIdentifier(download)
        if let id = downloadMap[key],
           let index = downloadManager.downloads.firstIndex(where: { $0.id == id }) {
            downloadManager.downloads[index].filename = suggestedFilename
        }
    }

    @available(iOS 14.5, *)
    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        defer {
            downloadMap.removeValue(forKey: key)
            downloadProgressObservers.removeValue(forKey: key)
            downloadDestinations.removeValue(forKey: key)
        }

        guard let id = downloadMap[key],
              let fileURL = downloadDestinations[key] else {
            return
        }
        downloadManager.completeWebKitDownload(id: id, localURL: fileURL)
    }

    @available(iOS 14.5, *)
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        defer {
            downloadMap.removeValue(forKey: key)
            downloadProgressObservers.removeValue(forKey: key)
            downloadDestinations.removeValue(forKey: key)
        }

        if let id = downloadMap[key] {
            downloadManager.failWebKitDownload(id: id, error: error)
        }
    }
}
