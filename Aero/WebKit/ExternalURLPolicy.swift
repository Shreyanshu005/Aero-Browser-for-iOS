import Foundation
import UIKit

struct ExternalURLPolicy {
    enum Decision: Equatable {
        case allowInWebView
        case openExternally(URL)
        case cancel
    }

    init() {}

    private let webViewSchemes: Set<String> = [
        "http",
        "https",
        "about",
        "aero",
    ]

    private let blockedSchemes: Set<String> = [
        "blob",
        "data",
        "file",
        "ftp",
        "javascript",
        "webkit-fake-url",
        "ws",
        "wss",
    ]

    func decision(for url: URL?) -> Decision {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              !scheme.isEmpty else {
            return .cancel
        }

        if webViewSchemes.contains(scheme) {
            return .allowInWebView
        }

        if blockedSchemes.contains(scheme) {
            return .cancel
        }

        return .openExternally(url)
    }
}

protocol ExternalURLOpening {
    func open(_ url: URL)
}

struct UIApplicationExternalURLOpener: ExternalURLOpening {
    func open(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
