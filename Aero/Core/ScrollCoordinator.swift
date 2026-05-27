import WebKit

final class ScrollCoordinator: NSObject, UIScrollViewDelegate {
    let onScroll: (WebScrollMetrics) -> Void
    
    init(onScroll: @escaping (WebScrollMetrics) -> Void) {
        self.onScroll = onScroll
        super.init()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let metrics = WebScrollMetrics(
            offsetY: max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top),
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height
        )
        onScroll(metrics)
    }
}


