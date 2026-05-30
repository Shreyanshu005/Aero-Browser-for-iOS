import SwiftUI
import Observation

@Observable
final class SheetRouter {

    var activeSheet: ActiveSheet?

    var activeFullScreenCover: ActiveFullScreenCover?

    enum ActiveSheet: Identifiable {
        case menu
        case history
        case bookmarks
        case downloads
        case settings
        case addBookmark
        case trackerReceipt

        var id: Int { hashValue }
    }

    enum ActiveFullScreenCover: Identifiable {
        case readerMode
        case findInPage

        var id: Int { hashValue }
    }

    func present(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }

    func presentFullScreen(_ cover: ActiveFullScreenCover) {
        activeFullScreenCover = cover
    }

    func dismiss() {
        activeSheet = nil
        activeFullScreenCover = nil
    }

    func dismissSheet() {
        activeSheet = nil
    }

    func dismissFullScreenCover() {
        activeFullScreenCover = nil
    }
}
