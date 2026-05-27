import Foundation

struct SecuritySummary: Equatable {
    enum Status: Equatable {
        case noPage
        case browserPage
        case secureHTTPS
        case insecureHTTP
        case nonWebScheme
    }

    struct DetailRow: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    let url: URL?
    let host: String
    let scheme: String
    let status: Status
    let certificateSummary: CertificateSummary?

    init(url: URL?, certificateSummary: CertificateSummary? = nil) {
        self.url = url
        self.host = url?.displayHost ?? url?.host ?? "No host"
        self.scheme = url?.scheme?.uppercased() ?? "None"
        let computedStatus = SecuritySummary.status(for: url)
        self.status = computedStatus

        if computedStatus == .secureHTTPS,
           let certificateSummary,
           certificateSummary.matches(host: url?.host) {
            self.certificateSummary = certificateSummary
        } else {
            self.certificateSummary = nil
        }
    }

    var isSecure: Bool {
        status == .secureHTTPS
    }

    var isHTTPS: Bool {
        url?.scheme?.lowercased() == "https"
    }

    var title: String {
        switch status {
        case .noPage:
            return "No Page Loaded"
        case .browserPage:
            return "Browser Page"
        case .secureHTTPS:
            return "Secure Connection"
        case .insecureHTTP:
            return "Not Secure"
        case .nonWebScheme:
            return "Connection Details"
        }
    }

    var explanation: String {
        switch status {
        case .noPage:
            return "Open a website to view connection details."
        case .browserPage:
            return "This is a local Aero page, not a remote website connection."
        case .secureHTTPS:
            return "This page was loaded over HTTPS, so traffic between Aero and the site is encrypted in transit."
        case .insecureHTTP:
            return "This page was loaded over HTTP. Traffic is not encrypted and may be visible or modified on the network."
        case .nonWebScheme:
            return "This page uses a non-web URL scheme, so HTTPS certificate details do not apply."
        }
    }

    var httpsStatus: String {
        switch status {
        case .secureHTTPS:
            return "Enabled"
        case .insecureHTTP:
            return "Not enabled"
        case .noPage, .browserPage, .nonWebScheme:
            return "Not applicable"
        }
    }

    var certificateStatus: String {
        guard isHTTPS else { return "Not applicable" }
        guard let certificateSummary else { return "Not available" }
        return certificateSummary.subject
    }

    var detailRows: [DetailRow] {
        var rows = [
            DetailRow(id: "host", label: "Host", value: host),
            DetailRow(id: "scheme", label: "Scheme", value: scheme),
            DetailRow(id: "https", label: "HTTPS", value: httpsStatus),
            DetailRow(id: "certificate", label: "Certificate", value: certificateStatus),
        ]

        if let certificateSummary {
            rows.append(
                DetailRow(
                    id: "certificate-count",
                    label: "Chain",
                    value: "\(certificateSummary.certificateCount) certificate\(certificateSummary.certificateCount == 1 ? "" : "s")"
                )
            )

            if let fingerprint = certificateSummary.shortFingerprint {
                rows.append(DetailRow(id: "fingerprint", label: "SHA-256", value: fingerprint))
            }
        }

        return rows
    }

    private static func status(for url: URL?) -> Status {
        guard let url else { return .noPage }

        let scheme = url.scheme?.lowercased()
        switch scheme {
        case "about", "aero":
            return .browserPage
        case "https":
            return .secureHTTPS
        case "http":
            return .insecureHTTP
        default:
            return .nonWebScheme
        }
    }
}

struct CertificateSummary: Equatable {
    let host: String
    let subject: String
    let certificateCount: Int
    let fingerprintSHA256: String?

    var shortFingerprint: String? {
        guard let fingerprintSHA256 else { return nil }
        let visiblePrefix = fingerprintSHA256.prefix(23)
        return fingerprintSHA256.count > visiblePrefix.count
            ? "\(visiblePrefix)..."
            : fingerprintSHA256
    }

    func matches(host otherHost: String?) -> Bool {
        guard let otherHost else { return false }
        return Self.normalizedHost(host) == Self.normalizedHost(otherHost)
    }

    private static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
    }
}
