
import AVKit
import Foundation
import WebKit
import os.log

// MARK: - PictureInPictureError

/// Errors that can occur during PiP operations.
enum PictureInPictureError: LocalizedError {
    case noVideoFound
    case invalidVideoURL
    case webViewUnavailable
    case pipNotSupported
    case javaScriptError(String)

    var errorDescription: String? {
        switch self {
        case .noVideoFound:
            return "No playable video was found on this page."
        case .invalidVideoURL:
            return "The video URL could not be resolved."
        case .webViewUnavailable:
            return "The web view is not available."
        case .pipNotSupported:
            return "Picture-in-Picture is not supported on this device."
        case .javaScriptError(let message):
            return "JavaScript error: \(message)"
        }
    }
}

// MARK: - VideoInfo

/// Describes a video element found on a web page.
struct VideoInfo: Sendable {
    /// The source URL of the video (may be empty for blob URLs without fallback).
    let sourceURL: String
    /// The current playback time in seconds.
    let currentTime: Double
    /// Whether the video is currently paused.
    let isPaused: Bool
    /// Whether the source is a blob URL.
    let isBlobURL: Bool
    /// The video's duration in seconds.
    let duration: Double
}

// MARK: - PictureInPictureService

/// Detects videos on web pages and provides Picture-in-Picture playback.
///
/// Uses JavaScript injection to find `<video>` elements and extract their
/// source URLs. Supports direct HTTP(S) URLs; blob URLs are detected and
/// the service attempts to resolve the underlying source.
@Observable
final class PictureInPictureService {

    // MARK: - Public State

    /// The currently active PiP player controller, if any.
    var activePlayerController: AVPlayerViewController?

    /// Whether PiP is currently active.
    var isPiPActive: Bool = false

    // MARK: - Private

    private var player: AVPlayer?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.aero.browser", category: "PictureInPicture")

    // MARK: - JavaScript Sources

    /// JavaScript to detect all video elements on the page and return their metadata.
    private static let detectVideoJS = """
    (function() {
        var videos = document.querySelectorAll('video');
        if (videos.length === 0) return JSON.stringify({ found: false, videos: [] });

        var results = [];
        for (var i = 0; i < videos.length; i++) {
            var v = videos[i];
            var src = v.currentSrc || v.src || '';

            if (!src && v.querySelector('source')) {
                src = v.querySelector('source').src || '';
            }

            results.push({
                src: src,
                currentTime: v.currentTime || 0,
                isPaused: v.paused,
                isBlobURL: src.indexOf('blob:') === 0,
                duration: v.duration || 0,
                width: v.videoWidth || 0,
                height: v.videoHeight || 0
            });
        }
        return JSON.stringify({ found: true, videos: results });
    })();
    """

    /// JavaScript to extract the resolved source URL from the largest video element.
    private static let extractSourceJS = """
    (function() {
        var videos = Array.from(document.querySelectorAll('video'));
        if (videos.length === 0) return '';

        videos.sort(function(a, b) {
            return (b.videoWidth * b.videoHeight) - (a.videoWidth * a.videoHeight);
        });

        var v = videos[0];
        var src = v.currentSrc || v.src || '';

        if (src.indexOf('blob:') === 0) {
            var sources = v.querySelectorAll('source');
            for (var i = 0; i < sources.length; i++) {
                var s = sources[i].src || '';
                if (s && s.indexOf('blob:') !== 0) {
                    return s;
                }
            }

            var dataAttrs = ['data-src', 'data-url', 'data-video-src'];
            for (var j = 0; j < dataAttrs.length; j++) {
                var val = v.getAttribute(dataAttrs[j]);
                if (val && val.indexOf('blob:') !== 0) {
                    return val;
                }
            }
        }

        return src;
    })();
    """

    // MARK: - Public Methods

    /// Detects whether the current page contains any video elements.
    ///
    /// - Parameter webView: The web view to inspect.
    /// - Returns: An array of `VideoInfo` structs for each detected video.
    func detectVideos(in webView: WKWebView) async throws -> [VideoInfo] {
        let result = try await webView.evaluateJavaScript(Self.detectVideoJS)

        guard let jsonString = result as? String,
              let jsonData = jsonString.data(using: .utf8) else {
            throw PictureInPictureError.noVideoFound
        }

        let decoded = try JSONDecoder().decode(DetectVideoResponse.self, from: jsonData)
        guard decoded.found else {
            throw PictureInPictureError.noVideoFound
        }

        return decoded.videos.map { entry in
            VideoInfo(
                sourceURL: entry.src,
                currentTime: entry.currentTime,
                isPaused: entry.isPaused,
                isBlobURL: entry.isBlobURL,
                duration: entry.duration
            )
        }
    }

    /// Extracts the best available video source URL from the page.
    ///
    /// - Parameter webView: The web view to inspect.
    /// - Returns: The resolved video URL.
    func extractVideoSourceURL(from webView: WKWebView) async throws -> URL {
        let result = try await webView.evaluateJavaScript(Self.extractSourceJS)

        guard let urlString = result as? String, !urlString.isEmpty else {
            throw PictureInPictureError.noVideoFound
        }

        if urlString.hasPrefix("blob:") {
            logger.warning("Detected blob URL — attempting page-level source extraction")
            throw PictureInPictureError.invalidVideoURL
        }

        guard let url = URL(string: urlString) else {
            throw PictureInPictureError.invalidVideoURL
        }

        return url
    }

    /// Starts Picture-in-Picture playback for the primary video on the page.
    ///
    /// - Parameter webView: The web view containing the video.
    /// - Returns: The configured `AVPlayerViewController` for presentation.
    @MainActor
    func startPiP(from webView: WKWebView) async throws -> AVPlayerViewController {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            throw PictureInPictureError.pipNotSupported
        }

        let videoURL = try await extractVideoSourceURL(from: webView)
        logger.info("Starting PiP with URL: \(videoURL.absoluteString)")

        let videos = try? await detectVideos(in: webView)
        let currentTime = videos?.first?.currentTime ?? 0

        let playerItem = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        self.player = avPlayer

        if currentTime > 0 {
            let seekTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            await avPlayer.seek(to: seekTime)
        }

        let controller = AVPlayerViewController()
        controller.player = avPlayer
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true

        self.activePlayerController = controller
        self.isPiPActive = true

        try? await webView.evaluateJavaScript(
            "document.querySelectorAll('video').forEach(function(v) { v.pause(); });"
        )

        avPlayer.play()
        return controller
    }

    /// Stops PiP playback and cleans up resources.
    @MainActor
    func stopPiP() {
        player?.pause()
        player = nil
        activePlayerController = nil
        isPiPActive = false
        logger.info("PiP stopped")
    }
}

// MARK: - Decodable Response Types

private struct DetectVideoResponse: Decodable {
    let found: Bool
    let videos: [DetectVideoEntry]
}

private struct DetectVideoEntry: Decodable {
    let src: String
    let currentTime: Double
    let isPaused: Bool
    let isBlobURL: Bool
    let duration: Double
    let width: Int
    let height: Int
}
