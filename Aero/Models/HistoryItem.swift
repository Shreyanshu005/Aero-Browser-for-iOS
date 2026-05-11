






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


    var dayKey: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(visitDate) {
            return "Today"
        } else if calendar.isDateInYesterday(visitDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: visitDate)
        }
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: visitDate)
    }
}
