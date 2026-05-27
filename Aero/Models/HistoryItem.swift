import Foundation

struct HistoryItem: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    let title: String
    let visitDate: Date

    init(url: URL, title: String, visitDate: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.title = title.isEmpty ? url.displayHost ?? url.absoluteString : title
        self.visitDate = visitDate
    }
}

// MARK: - Formatting (separated from model to avoid per-access DateFormatter allocation)

enum HistoryItemFormatter {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    static func dayKey(for item: HistoryItem) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(item.visitDate) {
            return "Today"
        } else if calendar.isDateInYesterday(item.visitDate) {
            return "Yesterday"
        } else {
            return dayFormatter.string(from: item.visitDate)
        }
    }

    static func timeString(for item: HistoryItem) -> String {
        timeFormatter.string(from: item.visitDate)
    }
}

// MARK: - Convenience accessors (delegates to formatter)

extension HistoryItem {
    var dayKey: String {
        HistoryItemFormatter.dayKey(for: self)
    }

    var timeString: String {
        HistoryItemFormatter.timeString(for: self)
    }
}
