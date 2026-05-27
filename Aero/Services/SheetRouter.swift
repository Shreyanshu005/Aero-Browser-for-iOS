
import SwiftUI
import Observation

/// Manages presentation of modal sheets and full-screen covers using a single enum
/// instead of multiple separate boolean flags.
///
/// This replaces the pattern of having `showMenu`, `showHistory`, `showBookmarks`, etc.
/// as individual `Bool` properties, centralising presentation state and ensuring that
/// only one sheet or cover is active at a time.
///
/// ## Usage
/// ```swift
/// // In a view model
/// let sheetRouter = SheetRouter()
///
/// // Present a sheet
/// sheetRouter.present(.history)
///
/// // In a SwiftUI view
/// .sheet(item: $viewModel.sheetRouter.activeSheet) { sheet in
///     switch sheet {
///     case .history: HistoryView()
///     case .bookmarks: BookmarksView()
///     // ...
///     }
/// }
/// ```
@Observable
final class SheetRouter {

    // MARK: - State

    /// The currently presented modal sheet, or `nil` if no sheet is showing.
    var activeSheet: ActiveSheet?

    /// The currently presented full-screen cover, or `nil` if no cover is showing.
    var activeFullScreenCover: ActiveFullScreenCover?

    // MARK: - Sheet Types

    /// Modal sheets presented as half/full sheets via `.sheet(item:)`.
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

    /// Full-screen covers presented via `.fullScreenCover(item:)`.
    enum ActiveFullScreenCover: Identifiable {
        case readerMode
        case findInPage

        var id: Int { hashValue }
    }

    // MARK: - Presentation

    /// Presents the given sheet, dismissing any currently active sheet first.
    /// - Parameter sheet: The sheet to present.
    func present(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }

    /// Presents the given full-screen cover, dismissing any currently active cover first.
    /// - Parameter cover: The full-screen cover to present.
    func presentFullScreen(_ cover: ActiveFullScreenCover) {
        activeFullScreenCover = cover
    }

    // MARK: - Dismissal

    /// Dismisses both the active sheet and the active full-screen cover.
    func dismiss() {
        activeSheet = nil
        activeFullScreenCover = nil
    }

    /// Dismisses only the active sheet, leaving any full-screen cover intact.
    func dismissSheet() {
        activeSheet = nil
    }

    /// Dismisses only the active full-screen cover, leaving any sheet intact.
    func dismissFullScreenCover() {
        activeFullScreenCover = nil
    }
}
