
import UIKit

/// Thread-safe actor-based LRU favicon cache with three lookup tiers:
/// 1. **Memory** — `NSCache` with a 100-item limit for instant access.
/// 2. **Disk** — PNG files in `Caches/Favicons/` for persistence across app launches.
/// 3. **Network** — Fetches from the page's `<link rel="icon">` or falls back to `/favicon.ico`.
///
/// ## Usage
/// ```swift
/// let cache = FaviconCache.shared
/// if let favicon = await cache.favicon(for: "apple.com") {
///     imageView.image = favicon
/// }
/// ```
actor FaviconCache {

    // MARK: - Shared Instance

    /// The shared singleton cache instance.
    static let shared = FaviconCache()

    // MARK: - Memory Cache

    /// Wrapper to allow `UIImage` values in `NSCache` (which requires `AnyObject` values).
    private final class CacheEntry {
        let image: UIImage
        init(image: UIImage) { self.image = image }
    }

    /// In-memory LRU cache backed by `NSCache`.
    private let memoryCache: NSCache<NSString, CacheEntry> = {
        let cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = 100
        cache.name = "com.aero.faviconCache"
        return cache
    }()

    // MARK: - Disk Cache

    /// The directory where favicon PNGs are stored on disk.
    private let diskCacheDirectory: URL

    /// File manager used for disk operations.
    private let fileManager = FileManager.default

    // MARK: - Network

    /// URL session used for favicon network requests.
    private let urlSession: URLSession

    /// Set of hosts currently being fetched to avoid duplicate network requests.
    private var inFlightHosts: Set<String> = []

    // MARK: - Initialization

    /// Creates a new favicon cache.
    ///
    /// - Parameter urlSession: The URL session to use for network requests. Defaults to `.shared`.
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession

        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.diskCacheDirectory = cachesDir.appendingPathComponent("Favicons", isDirectory: true)

        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Retrieves the favicon for the given host, checking memory, disk, and network in order.
    ///
    /// - Parameter host: The hostname (e.g., `"apple.com"`).
    /// - Returns: The favicon image, or `nil` if no favicon could be found.
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

    /// Stores a favicon in both memory and disk caches for the given host.
    ///
    /// - Parameters:
    ///   - image: The favicon image to cache.
    ///   - host: The hostname to associate the image with.
    func setFavicon(_ image: UIImage, for host: String) {
        let cacheKey = sanitizedKey(for: host)
        memoryCache.setObject(CacheEntry(image: image), forKey: cacheKey as NSString)
        saveToDisk(image: image, key: cacheKey)
    }

    /// Removes the cached favicon for the given host from both memory and disk.
    ///
    /// - Parameter host: The hostname whose favicon should be evicted.
    func removeFavicon(for host: String) {
        let cacheKey = sanitizedKey(for: host)
        memoryCache.removeObject(forKey: cacheKey as NSString)
        let fileURL = diskFileURL(for: cacheKey)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Clears all cached favicons from both memory and disk.
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDirectory)
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Disk Operations

    /// Returns the file URL for a cached favicon on disk.
    private func diskFileURL(for key: String) -> URL {
        diskCacheDirectory.appendingPathComponent("\(key).png")
    }

    /// Loads a favicon from the disk cache.
    private func loadFromDisk(key: String) -> UIImage? {
        let fileURL = diskFileURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Saves a favicon to the disk cache as a PNG.
    private func saveToDisk(image: UIImage, key: String) {
        guard let data = image.pngData() else { return }
        let fileURL = diskFileURL(for: key)
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Network Fetching

    /// Attempts to fetch a favicon from the network.
    ///
    /// Strategy:
    /// 1. Try fetching the page at the host and look for `<link rel="icon">` in the HTML.
    /// 2. Fall back to `https://{host}/favicon.ico`.
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

    /// Downloads an image from the given URL.
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

    /// Discovers the favicon URL by fetching the page HTML and parsing `<link rel="icon">`.
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

    /// Extracts the icon href from HTML content using simple string matching.
    ///
    /// This avoids pulling in a full HTML parser for a single attribute extraction.
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

    /// Extracts the `href` attribute value from a tag string.
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

    // MARK: - Helpers

    /// Sanitizes a hostname into a safe filesystem key.
    private func sanitizedKey(for host: String) -> String {
        host.lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
}
