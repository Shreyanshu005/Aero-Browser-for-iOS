import WebKit

/// Protocol defining the interface for content blocking services.
///
/// Conforming types compile content-blocking rules (e.g., ad/tracker filters)
/// and apply or remove them from a `WKWebViewConfiguration`. This abstraction
/// allows unit tests to provide a mock blocker without compiling real WebKit rules.
protocol ContentBlockerProtocol {
    /// Whether the content blocking rules have been successfully compiled and are ready to use.
    var isCompiled: Bool { get }

    /// The cumulative number of trackers/resources blocked since the blocker was applied.
    var blockedTrackerCount: Int { get }

    /// Compiles the content blocking rules asynchronously.
    ///
    /// After successful compilation, `isCompiled` will return `true` and the rules
    /// can be applied to a web view configuration.
    ///
    /// - Throws: An error if the rules fail to compile (e.g., invalid JSON syntax).
    func compileRules() async throws

    /// Applies the compiled content blocking rules to the given web view configuration.
    ///
    /// This adds the rule list to the configuration's user content controller.
    /// Calling this before `compileRules()` completes has no effect.
    ///
    /// - Parameter configuration: The `WKWebViewConfiguration` to apply rules to.
    func apply(to configuration: WKWebViewConfiguration)

    /// Removes all content blocking rules from the given web view configuration.
    ///
    /// - Parameter configuration: The `WKWebViewConfiguration` to remove rules from.
    func remove(from configuration: WKWebViewConfiguration)
}
