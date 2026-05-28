import Foundation

@MainActor
struct BrowserActionExecutor {
    private let maxWaitMilliseconds: Int

    init(maxWaitMilliseconds: Int = 10_000) {
        self.maxWaitMilliseconds = max(0, maxWaitMilliseconds)
    }

    func execute(_ request: BrowserActionRequest, in target: BrowserActionTarget) async -> BrowserActionResult {
        switch request.kind {
        case .openURL:
            return executeOpenURL(request, in: target)
        case .clickElement:
            return await executeElementAction(request, in: target)
        case .typeText:
            return await executeElementAction(request, in: target)
        case .clearField:
            return await executeElementAction(request, in: target)
        case .pressEnter:
            return await executeElementAction(request, in: target)
        case .scroll:
            return await executeScroll(request, in: target)
        case .wait:
            return await executeWait(request, in: target)
        case .back:
            return executeBack(request, in: target)
        case .forward:
            return executeForward(request, in: target)
        case .reload:
            return executeReload(request, in: target)
        case .stop:
            return executeStop(request, in: target)
        }
    }

    private func executeOpenURL(_ request: BrowserActionRequest, in target: BrowserActionTarget) -> BrowserActionResult {
        guard let rawURL = request.url?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return result(
                for: request.kind,
                in: target,
                code: .invalidRequest,
                message: "Open URL requires a non-empty URL."
            )
        }

        guard let url = normalizedURL(from: rawURL) else {
            return result(
                for: request.kind,
                in: target,
                code: .invalidURL,
                message: "URL is not valid."
            )
        }

        guard isSupportedWebURL(url) else {
            return result(
                for: request.kind,
                in: target,
                code: .unsupportedURL,
                message: "URL scheme is not supported for browser actions."
            )
        }

        target.browserActionOpenURL(url)
        return result(for: request.kind, in: target, code: .success, message: "Opened URL.")
    }

    private func executeElementAction(_ request: BrowserActionRequest, in target: BrowserActionTarget) async -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionHasWebView else {
            return result(for: request.kind, in: target, code: .missingWebView, message: "Active tab does not have a web view.")
        }

        switch request.kind {
        case .clickElement:
            guard let elementID = validElementID(request.elementID) else {
                return result(for: request.kind, in: target, code: .invalidRequest, message: "Click requires an element ID.")
            }
            return await evaluate(
                BrowserActionJavaScript.clickElement(id: elementID, userApproved: request.userApproved),
                for: request.kind,
                in: target
            )
        case .typeText:
            guard let text = request.text else {
                return result(for: request.kind, in: target, code: .invalidRequest, message: "Type text requires text.")
            }
            return await evaluate(
                BrowserActionJavaScript.typeText(id: validElementID(request.elementID), text: text),
                for: request.kind,
                in: target
            )
        case .clearField:
            return await evaluate(
                BrowserActionJavaScript.clearField(id: validElementID(request.elementID)),
                for: request.kind,
                in: target
            )
        case .pressEnter:
            return await evaluate(
                BrowserActionJavaScript.pressEnter(id: validElementID(request.elementID), userApproved: request.userApproved),
                for: request.kind,
                in: target
            )
        default:
            return result(for: request.kind, in: target, code: .invalidRequest, message: "Unsupported element action.")
        }
    }

    private func executeScroll(_ request: BrowserActionRequest, in target: BrowserActionTarget) async -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionHasWebView else {
            return result(for: request.kind, in: target, code: .missingWebView, message: "Active tab does not have a web view.")
        }

        guard let scroll = request.scroll else {
            return result(for: request.kind, in: target, code: .invalidRequest, message: "Scroll requires a direction.")
        }

        return await evaluate(BrowserActionJavaScript.scroll(scroll), for: request.kind, in: target)
    }

    private func executeWait(_ request: BrowserActionRequest, in target: BrowserActionTarget) async -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        let requestedMilliseconds = request.waitMilliseconds ?? 0
        let milliseconds = min(max(0, requestedMilliseconds), maxWaitMilliseconds)
        if milliseconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
        }

        return result(for: request.kind, in: target, code: .success, message: "Waited \(milliseconds) ms.")
    }

    private func executeBack(_ request: BrowserActionRequest, in target: BrowserActionTarget) -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionCanGoBack else {
            return result(for: request.kind, in: target, code: .navigationUnavailable, message: "No back navigation is available.")
        }

        target.browserActionGoBack()
        return result(for: request.kind, in: target, code: .success, message: "Navigated back.")
    }

    private func executeForward(_ request: BrowserActionRequest, in target: BrowserActionTarget) -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionCanGoForward else {
            return result(for: request.kind, in: target, code: .navigationUnavailable, message: "No forward navigation is available.")
        }

        target.browserActionGoForward()
        return result(for: request.kind, in: target, code: .success, message: "Navigated forward.")
    }

    private func executeReload(_ request: BrowserActionRequest, in target: BrowserActionTarget) -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionHasWebView else {
            return result(for: request.kind, in: target, code: .missingWebView, message: "Active tab does not have a web view.")
        }

        target.browserActionReload()
        return result(for: request.kind, in: target, code: .success, message: "Reloaded page.")
    }

    private func executeStop(_ request: BrowserActionRequest, in target: BrowserActionTarget) -> BrowserActionResult {
        guard target.browserActionTabID != nil else {
            return result(for: request.kind, in: target, code: .noActiveTab, message: "No active tab is available.")
        }

        guard target.browserActionHasWebView else {
            return result(for: request.kind, in: target, code: .missingWebView, message: "Active tab does not have a web view.")
        }

        target.browserActionStopLoading()
        return result(for: request.kind, in: target, code: .success, message: "Stopped loading.")
    }

    private func evaluate(
        _ javaScript: String,
        for action: BrowserActionKind,
        in target: BrowserActionTarget
    ) async -> BrowserActionResult {
        do {
            let rawResult = try await target.browserActionEvaluateJavaScript(javaScript)
            guard let scriptResult = decodeScriptResult(rawResult) else {
                return result(for: action, in: target, code: .javaScriptFailed, message: "Browser action returned an invalid result.")
            }

            return result(
                for: action,
                in: target,
                code: scriptResult.code,
                message: scriptResult.message,
                element: scriptResult.element,
                scroll: scriptResult.scroll
            )
        } catch BrowserActionExecutionError.missingWebView {
            return result(for: action, in: target, code: .missingWebView, message: "Active tab does not have a web view.")
        } catch {
            return result(for: action, in: target, code: .javaScriptFailed, message: error.localizedDescription)
        }
    }

    private func decodeScriptResult(_ rawResult: Any?) -> BrowserActionScriptResult? {
        guard let json = rawResult as? String,
              let data = json.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(BrowserActionScriptResult.self, from: data)
    }

    private func result(
        for action: BrowserActionKind,
        in target: BrowserActionTarget,
        code: BrowserActionResultCode,
        message: String,
        element: BrowserElementActionSummary? = nil,
        scroll: BrowserScrollState? = nil
    ) -> BrowserActionResult {
        BrowserActionResult(
            status: status(for: code),
            code: code,
            message: message,
            action: action,
            tabID: target.browserActionTabID,
            pageURL: target.browserActionPageURL,
            pageTitle: target.browserActionPageTitle,
            isLoading: target.browserActionIsLoading,
            canGoBack: target.browserActionCanGoBack,
            canGoForward: target.browserActionCanGoForward,
            element: element,
            scroll: scroll
        )
    }

    private func status(for code: BrowserActionResultCode) -> BrowserActionStatus {
        switch code {
        case .success:
            return .succeeded
        case .approvalRequired:
            return .approvalRequired
        default:
            return .failed
        }
    }

    private func validElementID(_ elementID: BrowserElementID?) -> BrowserElementID? {
        guard let rawValue = elementID?.rawValue.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawValue.isEmpty else {
            return nil
        }
        return BrowserElementID(rawValue: rawValue)
    }

    private func normalizedURL(from rawValue: String) -> URL? {
        if rawValue.hasPrefix("http://") || rawValue.hasPrefix("https://") {
            return URL(string: rawValue)
        }

        if URLComponents(string: rawValue)?.scheme != nil {
            return URL(string: rawValue)
        }

        if rawValue.looksLikeURL {
            return URL(string: "https://\(rawValue)")
        }

        return nil
    }

    private func isSupportedWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
}
