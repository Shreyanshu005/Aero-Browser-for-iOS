import WebKit
import UIKit

final class ThemeExtractor {
    static func updateThemeColor(from webView: WKWebView, for tab: Tab) {
        let js = """
        (function() {
          try {
            var meta = document.querySelector('meta[name="theme-color"]');
            if (meta && meta.content) return meta.content;
            var bodyBg = window.getComputedStyle(document.body).backgroundColor;
            if (bodyBg && bodyBg !== 'rgba(0, 0, 0, 0)' && bodyBg !== 'transparent') return bodyBg;
            var docBg = window.getComputedStyle(document.documentElement).backgroundColor;
            if (docBg) return docBg;
          } catch (e) {}
          return null;
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            let color = Self.parseCSSColor(result as? String) ?? UIColor.systemBackground
            DispatchQueue.main.async {
                tab.pageBackgroundColor = color
                webView.scrollView.backgroundColor = color
                webView.backgroundColor = color
                if #available(iOS 15.0, *) {
                    webView.underPageBackgroundColor = color
                }
            }
        }
    }

    private static func parseCSSColor(_ string: String?) -> UIColor? {
        guard var s = string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        s = s.lowercased()

        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            func hexToInt(_ sub: Substring) -> Int? { Int(sub, radix: 16) }
            if hex.count == 3,
               let r = hexToInt(hex.prefix(1)),
               let g = hexToInt(hex.dropFirst(1).prefix(1)),
               let b = hexToInt(hex.dropFirst(2).prefix(1)) {
                return UIColor(
                    red: CGFloat(r) / 15.0,
                    green: CGFloat(g) / 15.0,
                    blue: CGFloat(b) / 15.0,
                    alpha: 1
                )
            }
            if hex.count == 6,
               let r = hexToInt(hex.prefix(2)),
               let g = hexToInt(hex.dropFirst(2).prefix(2)),
               let b = hexToInt(hex.dropFirst(4).prefix(2)) {
                return UIColor(
                    red: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: 1
                )
            }
            return nil
        }

        if s.hasPrefix("rgb(") || s.hasPrefix("rgba(") {
            let start = s.firstIndex(of: "(")
            let end = s.lastIndex(of: ")")
            guard let start, let end, start < end else { return nil }
            let inner = s[s.index(after: start)..<end]
            let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3 else { return nil }

            func parseComponent(_ str: String) -> CGFloat? {
                if str.hasSuffix("%") {
                    let n = str.dropLast()
                    guard let v = Double(n) else { return nil }
                    return CGFloat(v / 100.0)
                }
                guard let v = Double(str) else { return nil }
                return CGFloat(v / 255.0)
            }

            guard let r = parseComponent(parts[0]),
                  let g = parseComponent(parts[1]),
                  let b = parseComponent(parts[2]) else { return nil }

            let a: CGFloat = {
                guard parts.count >= 4, let v = Double(parts[3]) else { return 1 }
                return CGFloat(max(0, min(1, v)))
            }()

            return UIColor(red: r, green: g, blue: b, alpha: a)
        }

        return nil
    }
}
