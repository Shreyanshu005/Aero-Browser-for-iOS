//
//  PageMetrics.swift
//  Aero
//
//  Created by Aero on 2026-05-27.
//

import Foundation

/// Container for page performance profiling data.
enum PagePerformanceProfiler {

    /// Aggregated metrics collected from a loaded web page.
    struct PageMetrics {
        /// Total page load time in seconds.
        var loadTime: TimeInterval = 0

        /// Number of sub-resources (scripts, stylesheets, images, etc.).
        var resourceCount: Int = 0

        /// Total transferred page weight in bytes.
        var pageWeight: Int64 = 0

        /// Number of DOM nodes in the document.
        var domNodes: Int = 0

        /// JavaScript heap size in bytes (0 when unavailable).
        var jsHeapSize: Int64 = 0
    }
}
