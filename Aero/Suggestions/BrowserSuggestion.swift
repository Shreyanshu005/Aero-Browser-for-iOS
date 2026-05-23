import Foundation

struct BrowserSuggestion: Identifiable, Hashable {
    enum Kind: Hashable {
        case tab
        case favorite
        case history

        var iconName: String {
            switch self {
            case .tab:
                return "rectangle.on.rectangle"
            case .favorite:
                return "bookmark.fill"
            case .history:
                return "clock.fill"
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let url: URL?
    let tabID: UUID?
}
