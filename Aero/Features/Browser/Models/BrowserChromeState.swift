import CoreGraphics

enum BottomChromeMode: Equatable {
    case expanded
    case compact
}

struct WebScrollMetrics: Equatable {
    let offsetY: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    var canScroll: Bool {
        contentHeight > viewportHeight + 24
    }

    var isNearTop: Bool {
        offsetY <= 12
    }

    var isNearBottom: Bool {
        (offsetY + viewportHeight) >= (contentHeight - 12)
    }
}

struct BrowserChromeController {
    private(set) var mode: BottomChromeMode = .expanded

    private var lastOffsetY: CGFloat?
    private var accumulatedDownScroll: CGFloat = 0
    private var accumulatedUpScroll: CGFloat = 0

    private let collapseThreshold: CGFloat = 96
    private let expandThreshold: CGFloat = 48

    mutating func handleScroll(_ metrics: WebScrollMetrics) {
        guard metrics.canScroll else {
            expand()
            return
        }

        guard !metrics.isNearTop else {
            expand()
            lastOffsetY = metrics.offsetY
            return
        }

        guard !metrics.isNearBottom else {
            lastOffsetY = metrics.offsetY
            accumulatedDownScroll = 0
            accumulatedUpScroll = 0
            return
        }

        guard let lastOffsetY else {
            self.lastOffsetY = metrics.offsetY
            return
        }

        let delta = metrics.offsetY - lastOffsetY
        self.lastOffsetY = metrics.offsetY

        guard abs(delta) >= 1 else { return }

        if delta > 0 {
            accumulatedDownScroll += delta
            accumulatedUpScroll = 0

            if accumulatedDownScroll >= collapseThreshold {
                mode = .compact
            }
        } else {
            accumulatedUpScroll += abs(delta)
            accumulatedDownScroll = 0

            if accumulatedUpScroll >= expandThreshold {
                mode = .expanded
            }
        }
    }

    mutating func expand() {
        mode = .expanded
        resetTracking()
    }

    mutating func resetTracking() {
        lastOffsetY = nil
        accumulatedDownScroll = 0
        accumulatedUpScroll = 0
    }
}

enum BrowserChromeLayout {
    static let compactTopInset: CGFloat = 0
    static let expandedBottomInset: CGFloat = 0
    static let focusedBottomInset: CGFloat = 0
    static let compactBottomInset: CGFloat = 0
}
