import WebKit

protocol ContentBlockerProtocol {

    var isCompiled: Bool { get }

    var blockedTrackerCount: Int { get }

    func compileRules() async throws

    func apply(to configuration: WKWebViewConfiguration)

    func remove(from configuration: WKWebViewConfiguration)
}
