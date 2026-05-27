import CryptoKit
import Foundation
import Security

enum CertificateSummaryParser {
    static func summary(from trust: SecTrust, host: String) -> CertificateSummary? {
        guard let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leafCertificate = certificates.first else {
            return nil
        }

        let subject = SecCertificateCopySubjectSummary(leafCertificate) as String? ?? host
        let data = SecCertificateCopyData(leafCertificate) as Data

        return CertificateSummary(
            host: host,
            subject: subject,
            certificateCount: certificates.count,
            fingerprintSHA256: sha256Fingerprint(for: data)
        )
    }

    private static func sha256Fingerprint(for data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02X", $0) }
            .joined(separator: ":")
    }
}
