import Foundation
import Testing
@testable import Aero

@MainActor
struct BrowserActionExecutorTests {

    @Test func openURLNormalizesHostLikeInput() async {
        let target = SpyBrowserActionTarget()
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .openURL, url: "example.com/path"),
            in: target
        )

        #expect(result.status == .succeeded)
        #expect(result.code == .success)
        #expect(target.openedURLs == [URL(string: "https://example.com/path")!])
    }

    @Test func openURLBlocksUnsupportedScheme() async {
        let target = SpyBrowserActionTarget()
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .openURL, url: "javascript:alert(1)"),
            in: target
        )

        #expect(result.status == .failed)
        #expect(result.code == .unsupportedURL)
        #expect(target.openedURLs.isEmpty)
    }

    @Test func clickRequiresElementID() async {
        let target = SpyBrowserActionTarget()
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .clickElement),
            in: target
        )

        #expect(result.status == .failed)
        #expect(result.code == .invalidRequest)
        #expect(target.evaluatedJavaScript.isEmpty)
    }

    @Test func clickReportsStaleElementID() async {
        let target = SpyBrowserActionTarget(
            javaScriptResults: [
                .success("""
                {"ok":false,"code":"elementMissing","message":"Element ID is stale or missing.","element":null,"scroll":null}
                """)
            ]
        )
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .clickElement, elementID: BrowserElementID(rawValue: "aero-1")),
            in: target
        )

        #expect(result.status == .failed)
        #expect(result.code == .elementMissing)
        #expect(result.message == "Element ID is stale or missing.")
        #expect(target.evaluatedJavaScript.count == 1)
    }

    @Test func clickPropagatesApprovalRequiredForSubmitLikeElement() async {
        let target = SpyBrowserActionTarget(
            javaScriptResults: [
                .success("""
                {"ok":false,"code":"approvalRequired","message":"Action may submit or share data and needs approval.","element":{"elementID":"submit-1","tagName":"button","role":null,"type":"submit","label":"Submit","isVisible":true,"isDisabled":false,"requiresApproval":true},"scroll":null}
                """)
            ]
        )
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .clickElement, elementID: BrowserElementID(rawValue: "submit-1")),
            in: target
        )

        #expect(result.status == .approvalRequired)
        #expect(result.code == .approvalRequired)
        #expect(result.element?.elementID == BrowserElementID(rawValue: "submit-1"))
        #expect(result.element?.requiresApproval == true)
    }

    @Test func typeFailsCleanlyWhenActiveTabHasNoWebView() async {
        let target = SpyBrowserActionTarget(hasWebView: false)
        let executor = BrowserActionExecutor()

        let result = await executor.execute(
            BrowserActionRequest(kind: .typeText, text: "hello"),
            in: target
        )

        #expect(result.status == .failed)
        #expect(result.code == .missingWebView)
        #expect(target.evaluatedJavaScript.isEmpty)
    }

    @Test func backFailsWhenNavigationUnavailable() async {
        let target = SpyBrowserActionTarget(canGoBack: false)
        let executor = BrowserActionExecutor()

        let result = await executor.execute(BrowserActionRequest(kind: .back), in: target)

        #expect(result.status == .failed)
        #expect(result.code == .navigationUnavailable)
        #expect(target.didGoBack == false)
    }

    @Test func backInvokesTargetWhenAvailable() async {
        let target = SpyBrowserActionTarget(canGoBack: true)
        let executor = BrowserActionExecutor()

        let result = await executor.execute(BrowserActionRequest(kind: .back), in: target)

        #expect(result.status == .succeeded)
        #expect(result.code == .success)
        #expect(target.didGoBack)
    }

    @Test func elementScriptTargetsHopperStylePublicIDAttribute() {
        let script = BrowserActionJavaScript.clickElement(
            id: BrowserElementID(rawValue: "aero-1"),
            userApproved: false
        )

        #expect(script.contains("data-aero-element-id"))
    }

    @Test func waitClampsDuration() async {
        let target = SpyBrowserActionTarget()
        let executor = BrowserActionExecutor(maxWaitMilliseconds: 0)

        let result = await executor.execute(
            BrowserActionRequest(kind: .wait, waitMilliseconds: 20_000),
            in: target
        )

        #expect(result.status == .succeeded)
        #expect(result.message == "Waited 0 ms.")
    }
}

@MainActor
private final class SpyBrowserActionTarget: BrowserActionTarget {
    var browserActionTabID: UUID?
    var browserActionPageURL: URL?
    var browserActionPageTitle: String?
    var browserActionIsLoading: Bool
    var browserActionCanGoBack: Bool
    var browserActionCanGoForward: Bool
    var browserActionHasWebView: Bool

    var openedURLs: [URL] = []
    var evaluatedJavaScript: [String] = []
    var didGoBack = false
    var didGoForward = false
    var didReload = false
    var didStopLoading = false

    private var javaScriptResults: [Result<Any?, Error>]

    init(
        tabID: UUID? = UUID(),
        pageURL: URL? = URL(string: "https://example.com"),
        pageTitle: String? = "Example",
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        hasWebView: Bool = true,
        javaScriptResults: [Result<Any?, Error>] = []
    ) {
        browserActionTabID = tabID
        browserActionPageURL = pageURL
        browserActionPageTitle = pageTitle
        browserActionIsLoading = isLoading
        browserActionCanGoBack = canGoBack
        browserActionCanGoForward = canGoForward
        browserActionHasWebView = hasWebView
        self.javaScriptResults = javaScriptResults
    }

    func browserActionOpenURL(_ url: URL) {
        openedURLs.append(url)
        browserActionPageURL = url
    }

    func browserActionGoBack() {
        didGoBack = true
    }

    func browserActionGoForward() {
        didGoForward = true
    }

    func browserActionReload() {
        didReload = true
    }

    func browserActionStopLoading() {
        didStopLoading = true
    }

    func browserActionEvaluateJavaScript(_ javaScript: String) async throws -> Any? {
        evaluatedJavaScript.append(javaScript)
        guard !javaScriptResults.isEmpty else {
            return """
            {"ok":true,"code":"success","message":"OK","element":null,"scroll":null}
            """
        }

        return try javaScriptResults.removeFirst().get()
    }
}
