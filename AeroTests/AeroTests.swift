import Testing
@testable import Aero

struct AeroTests {

    @Test func chromeStaysExpandedAtTop() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 0, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 8, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeDoesNotCollapseWhenPageCannotScroll() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 80, contentHeight: 780, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 140, contentHeight: 780, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeIgnoresBottomBounceJitter() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .compact)

        // Simulate bottom bounce where offset changes quickly near the bottom.
        controller.handleScroll(WebScrollMetrics(offsetY: 798, contentHeight: 800, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 790, contentHeight: 800, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 799, contentHeight: 800, viewportHeight: 800))

        #expect(controller.mode == .compact)
    }

    @Test func chromeDoesNotCollapseBeforeDownwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 120, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func chromeCollapsesAfterDownwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .compact)
    }

    @Test func chromeExpandsAfterUpwardScrollThreshold() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 88, contentHeight: 1600, viewportHeight: 800))

        #expect(controller.mode == .expanded)
    }

    @Test func forceExpandResetsChromeMode() {
        var controller = BrowserChromeController()

        controller.handleScroll(WebScrollMetrics(offsetY: 40, contentHeight: 1600, viewportHeight: 800))
        controller.handleScroll(WebScrollMetrics(offsetY: 138, contentHeight: 1600, viewportHeight: 800))
        controller.expand()

        #expect(controller.mode == .expanded)
    }

}
