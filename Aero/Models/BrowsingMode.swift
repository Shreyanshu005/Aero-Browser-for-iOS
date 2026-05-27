import Foundation

enum BrowsingMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case privateBrowsing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Tabs"
        case .privateBrowsing:
            return "Private"
        }
    }

    var systemImage: String {
        switch self {
        case .standard:
            return "square.on.square"
        case .privateBrowsing:
            return "eye.slash"
        }
    }

    var isSessionRestorable: Bool {
        self == .standard
    }

    func tabGridTitle(count: Int) -> String {
        switch self {
        case .standard:
            return "\(count) \(count == 1 ? "Tab" : "Tabs")"
        case .privateBrowsing:
            return "\(count) Private \(count == 1 ? "Tab" : "Tabs")"
        }
    }
}
