import WebKit
import Foundation

class Delegate: NSObject, WKNavigationDelegate {
    var isDone = false

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Started")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Finished loading: \(webView.url?.absoluteString ?? "")")
        isDone = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Failed: \(error)")
        isDone = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Failed provisional: \(error)")
        isDone = true
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("Action: \(navigationAction.request.url?.absoluteString ?? "")")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        print("Response: \(navigationResponse.response.url?.absoluteString ?? "")")
        decisionHandler(.allow)
    }
}

let webView = WKWebView()
let delegate = Delegate()
webView.navigationDelegate = delegate
webView.load(URLRequest(url: URL(string: "https://x.com")!))

let timeout = Date().addingTimeInterval(10)
while !delegate.isDone && Date() < timeout {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
}
print("Done")
