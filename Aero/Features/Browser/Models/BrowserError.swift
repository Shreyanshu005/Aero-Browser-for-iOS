import Foundation

struct BrowserError: Equatable {
    enum Kind: Equatable {
        case offline
        case connectionLost
        case timedOut
        case cannotFindServer
        case cannotConnect
        case secureConnectionFailed
        case unsupportedAddress
        case cancelled
        case unknown
    }

    let url: URL?
    let kind: Kind
    let underlyingDescription: String
    let underlyingDomain: String
    let underlyingCode: Int

    init(error: Error, url requestedURL: URL?) {
        let nsError = error as NSError
        let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL

        self.url = failingURL ?? requestedURL
        self.kind = Self.kind(for: nsError)
        self.underlyingDescription = nsError.localizedDescription
        self.underlyingDomain = nsError.domain
        self.underlyingCode = nsError.code
    }

    var displayHost: String {
        url?.displayHost ?? "This page"
    }

    var displayURL: String {
        url?.absoluteString ?? "Unknown address"
    }

    var title: String {
        switch kind {
        case .offline:
            return "You're offline"
        case .connectionLost:
            return "Connection dropped"
        case .timedOut:
            return "The page took too long"
        case .cannotFindServer:
            return "Website not found"
        case .cannotConnect:
            return "Can't reach the website"
        case .secureConnectionFailed:
            return "Secure connection failed"
        case .unsupportedAddress:
            return "Address not supported"
        case .cancelled:
            return "Navigation cancelled"
        case .unknown:
            return "Page failed to load"
        }
    }

    var message: String {
        switch kind {
        case .offline:
            return "Check your internet connection, then try again."
        case .connectionLost:
            return "The connection was interrupted before the page finished loading."
        case .timedOut:
            return "The server did not respond in time. It may be busy right now."
        case .cannotFindServer:
            return "Aero could not find a server for this address."
        case .cannotConnect:
            return "The server is unavailable or refused the connection."
        case .secureConnectionFailed:
            return "Aero could not verify this site's secure connection."
        case .unsupportedAddress:
            return "This address format is not supported."
        case .cancelled:
            return "The navigation was cancelled."
        case .unknown:
            return underlyingDescription.isEmpty
                ? "Something went wrong while loading this page."
                : underlyingDescription
        }
    }

    var shouldDisplay: Bool {
        kind != .cancelled
    }

    static func shouldDisplay(error: Error) -> Bool {
        BrowserError(error: error, url: nil).shouldDisplay
    }

    private static func kind(for error: NSError) -> Kind {
        if error.domain == "WebKitErrorDomain" && error.code == 102 {
            return .cancelled
        }

        guard error.domain == NSURLErrorDomain else {
            return .unknown
        }

        switch error.code {
        case NSURLErrorCancelled:
            return .cancelled
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff:
            return .offline
        case NSURLErrorNetworkConnectionLost:
            return .connectionLost
        case NSURLErrorTimedOut:
            return .timedOut
        case NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed:
            return .cannotFindServer
        case NSURLErrorCannotConnectToHost:
            return .cannotConnect
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot,
             NSURLErrorServerCertificateNotYetValid:
            return .secureConnectionFailed
        case NSURLErrorBadURL,
             NSURLErrorUnsupportedURL:
            return .unsupportedAddress
        default:
            return .unknown
        }
    }
}
