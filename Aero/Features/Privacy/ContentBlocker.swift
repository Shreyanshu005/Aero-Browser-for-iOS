






import WebKit

final class ContentBlocker {
    private var ruleList: WKContentRuleList?


    private let blockRulesJSON = #"""
    [
        {
            "trigger": { "url-filter": ".*(doubleclick\\.net|googlesyndication\\.com|googleadservices\\.com).*", "resource-type": ["script", "image"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*(facebook\\.net|connect\\.facebook\\.net|facebook\\.com/tr).*" },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*(analytics\\.google\\.com|google-analytics\\.com).*", "resource-type": ["script", "image"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\.ads\\..*" },
            "action": { "type": "block" }
        }
    ]
    """#

    @discardableResult
    func compileRules() async -> Bool {
        do {
            let list = try await WKContentRuleListStore.default()
                .compileContentRuleList(forIdentifier: "AeroBlocker", encodedContentRuleList: blockRulesJSON)
            self.ruleList = list
            return true
        } catch {
            print("[Aero] Content blocker compile error: \(error)")
            return false
        }
    }

    func apply(to configuration: WKWebViewConfiguration) {
        guard let ruleList = ruleList else { return }
        configuration.userContentController.add(ruleList)
    }

    func remove(from configuration: WKWebViewConfiguration) {
        configuration.userContentController.removeAllContentRuleLists()
    }
}
