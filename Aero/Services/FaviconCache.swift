import UIKit

actor FaviconCache {

    static let shared = FaviconCache()

    private final class CacheEntry {
        let image: UIImage
        init(image: UIImage) { self.image = image }
    }

    private let memoryCache: NSCache<NSString, CacheEntry> = {
        let cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100
        cache.name = "com.aero.faviconCache"
        return cache
    }()

    private let diskCacheDirectory: URL

    private let fileManager = FileManager.default

    private let urlSession: URLSession

    private var inFlightHosts: Set<String> = []

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession

        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.diskCacheDirectory = cachesDir.appendingPathComponent("Favicons", isDirectory: true)

        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    func favicon(for host: String) async -> UIImage? {
        let cacheKey = sanitizedKey(for: host)

        if let entry = memoryCache.object(forKey: cacheKey as NSString) {
            return entry.image
        }

        if let diskImage = loadFromDisk(key: cacheKey) {
            memoryCache.setObject(CacheEntry(image: diskImage), forKey: cacheKey as NSString)
            return diskImage
        }

        guard !inFlightHosts.contains(host) else { return nil }

        inFlightHosts.insert(host)
        defer { inFlightHosts.remove(host) }

        if let networkImage = await fetchFromNetwork(host: host) {
            memoryCache.setObject(CacheEntry(image: networkImage), forKey: cacheKey as NSString)
            saveToDisk(image: networkImage, key: cacheKey)
            return networkImage
        }

        return nil
    }

    func setFavicon(_ image: UIImage, for host: String) {
        let cacheKey = sanitizedKey(for: host)
        memoryCache.setObject(CacheEntry(image: image), forKey: cacheKey as NSString)
        saveToDisk(image: image, key: cacheKey)
    }

    func removeFavicon(for host: String) {
        let cacheKey = sanitizedKey(for: host)
        memoryCache.removeObject(forKey: cacheKey as NSString)
        let fileURL = diskFileURL(for: cacheKey)
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDirectory)
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    private func diskFileURL(for key: String) -> URL {
        diskCacheDirectory.appendingPathComponent("\(key).png")
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskFileURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.pngData() else { return }
        let fileURL = diskFileURL(for: key)
        try? data.write(to: fileURL, options: .atomic)
    }

    private func fetchFromNetwork(host: String) async -> UIImage? {
        if let iconURL = await discoverFaviconURL(for: host) {
            if let image = await downloadImage(from: iconURL) {
                return image
            }
        }

        if let fallbackURL = URL(string: "https://\(host)/favicon.ico") {
            if let image = await downloadImage(from: fallbackURL) {
                return image
            }
        }

        return nil
    }

    private func downloadImage(from url: URL) async -> UIImage? {
        do {
            let (data, response) = try await urlSession.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                return nil
            }

            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func discoverFaviconURL(for host: String) async -> URL? {
        guard let pageURL = URL(string: "https://\(host)") else { return nil }

        do {
            var request = URLRequest(url: pageURL)
            request.httpMethod = "GET"
            request.setValue("text/html", forHTTPHeaderField: "Accept")

            let (data, _) = try await urlSession.data(for: request)

            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return extractIconHref(from: html, baseHost: host)
        } catch {
            return nil
        }
    }

    private func extractIconHref(from html: String, baseHost: String) -> URL? {
        let patterns = [
            "rel=\"icon\"",
            "rel='icon'",
            "rel=\"shortcut icon\"",
            "rel='shortcut icon'",
            "rel=\"apple-touch-icon\"",
            "rel='apple-touch-icon'"
        ]

        let lowered = html.lowercased()

        for pattern in patterns {
            guard let relRange = lowered.range(of: pattern) else { continue }

            let searchStart = lowered.index(relRange.lowerBound, offsetBy: -200, limitedBy: lowered.startIndex) ?? lowered.startIndex
            let searchEnd = lowered.index(relRange.upperBound, offsetBy: 200, limitedBy: lowered.endIndex) ?? lowered.endIndex
            let tagRegion = String(html[searchStart..<searchEnd])

            if let href = extractHrefValue(from: tagRegion) {
                if href.hasPrefix("http://") || href.hasPrefix("https://") {
                    return URL(string: href)
                } else if href.hasPrefix("//") {
                    return URL(string: "https:\(href)")
                } else {
                    return URL(string: "https://\(baseHost)\(href.hasPrefix("/") ? href : "/\(href)")")
                }
            }
        }

        return nil
    }

    private func extractHrefValue(from tag: String) -> String? {
        let lowered = tag.lowercased()

        for quote in ["\"", "'"] {
            let prefix = "href=\(quote)"
            guard let startRange = lowered.range(of: prefix) else { continue }

            let valueStart = tag[startRange.upperBound...]
            guard let endIndex = valueStart.firstIndex(of: Character(quote)) else { continue }

            return String(valueStart[..<endIndex])
        }

        return nil
    }

    private func sanitizedKey(for host: String) -> String {
        host.lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
}
