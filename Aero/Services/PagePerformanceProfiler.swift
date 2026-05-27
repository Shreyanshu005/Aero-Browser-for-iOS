import Foundation
import Observation
import WebKit

struct PageMetrics: Equatable {
    let loadTime: TimeInterval
    let resourceCount: Int
    let pageWeight: Int64 // bytes
    let domNodes: Int
    let jsHeapSize: Int64
    
    static let empty = PageMetrics(loadTime: 0, resourceCount: 0, pageWeight: 0, domNodes: 0, jsHeapSize: 0)
}

@Observable
final class PagePerformanceProfiler {
    var isEnabled: Bool = false
    var latestMetrics: PageMetrics? = nil
    
    func profile(webView: WKWebView) async {
        guard isEnabled else { return }
        
        let js = """
        (function() {
            try {
                const timing = performance.timing;
                const loadTime = timing.loadEventEnd > 0 ? (timing.loadEventEnd - timing.navigationStart) / 1000 : 0;
                
                const resources = performance.getEntriesByType('resource');
                const resourceCount = resources.length;
                
                let pageWeight = 0;
                resources.forEach(r => {
                    pageWeight += (r.transferSize || r.decodedBodySize || 0);
                });
                
                const domNodes = document.querySelectorAll('*').length;
                
                const memory = performance.memory;
                const jsHeapSize = memory ? memory.usedJSHeapSize : 0;
                
                return {
                    loadTime: loadTime,
                    resourceCount: resourceCount,
                    pageWeight: pageWeight,
                    domNodes: domNodes,
                    jsHeapSize: jsHeapSize
                };
            } catch (e) {
                return null;
            }
        })();
        """
        
        do {
            if let result = try await webView.evaluateJavaScript(js) as? [String: Any] {
                let metrics = PageMetrics(
                    loadTime: result["loadTime"] as? TimeInterval ?? 0,
                    resourceCount: result["resourceCount"] as? Int ?? 0,
                    pageWeight: Int64(result["pageWeight"] as? Double ?? 0),
                    domNodes: result["domNodes"] as? Int ?? 0,
                    jsHeapSize: Int64(result["jsHeapSize"] as? Double ?? 0)
                )
                await MainActor.run {
                    self.latestMetrics = metrics
                }
            }
        } catch {
            print("Profiler error: \(error)")
        }
    }
}
