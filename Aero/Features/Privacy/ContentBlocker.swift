import WebKit

final class ContentBlocker {
    private var ruleList: WKContentRuleList?

    private let blockRulesJSON = """
    [
        {
            "trigger": { "url-filter": ".*", "resource-type": ["script"], "if-domain": ["*doubleclick.net", "*googlesyndication.com", "*googleadservices.com"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*", "if-domain": ["*facebook.net", "*facebook.com/tr*", "*connect.facebook.net"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*", "if-domain": ["*analytics.google.com", "*google-analytics.com"] },
            "action": { "type": "block" }
        },
        {
            "trigger": { "url-filter": ".*\\\\.ads\\\\..*" },
            "action": { "type": "block" }
        }
    ]
    """

    func compileRules() async {
        do {
            let list = try await WKContentRuleListStore.default()
                .compileContentRuleList(forIdentifier: "AeroBlocker", encodedContentRuleList: blockRulesJSON)
            self.ruleList = list
        } catch {
            print("[Aero] Content blocker compile error: \(error)")
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
