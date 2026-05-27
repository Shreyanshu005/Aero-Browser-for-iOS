import AVKit
import Foundation
import WebKit
import os.log

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

struct VideoInfo: Sendable {

    let sourceURL: String

    let currentTime: Double

    let isPaused: Bool

    let isBlobURL: Bool

    let duration: Double
}

@Observable
final class PictureInPictureService {

    var activePlayerController: AVPlayerViewController?

    var isPiPActive: Bool = false

    private var player: AVPlayer?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.aero.browser", category: "PictureInPicture")

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

    @MainActor
    func stopPiP() {
        player?.pause()
        player = nil
        activePlayerController = nil
        isPiPActive = false
        logger.info("PiP stopped")
    }
}

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
