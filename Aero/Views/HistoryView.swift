import SwiftUI
import SwiftData

struct HistoryView: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \HistoryItem.visitDate, order: .reverse) private var allItems: [HistoryItem]

    private var filteredItems: [HistoryItem] {
        if searchText.isEmpty {
            return allItems
        } else {
            let lowered = searchText.lowercased()
            return allItems.filter {
                $0.title.lowercased().contains(lowered) ||
                $0.url.absoluteString.lowercased().contains(lowered)
            }
        }
    }

    private var groupedItems: [(key: String, items: [HistoryItem])] {
        let items = filteredItems
        if items.isEmpty { return [] }
        if !searchText.isEmpty {
            return [("Search Results", items)]
        }

        let grouped = Dictionary(grouping: items, by: { $0.dayKey })
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Today" { return true }
            if k2 == "Today" { return false }
            if k1 == "Yesterday" { return true }
            if k2 == "Yesterday" { return false }
            return k1 > k2
        }
        return sortedKeys.map { (key: $0, items: grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allItems.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock", description: Text("Pages you visit will appear here"))
                } else {
                    List {
                        ForEach(groupedItems, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.items) { item in
                                    Button {
                                        viewModel.tabManager.loadInActiveTab(url: item.url)
                                        dismiss()
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.body)
                                                .foregroundStyle(Color(UIColor.label))
                                                .lineLimit(1)
                                            Text(item.url.displayHost ?? item.url.absoluteString)
                                                .font(.caption)
                                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search history")
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !allItems.isEmpty {
                        Button("Clear", role: .destructive) {
                            viewModel.historyStore.clearHistory()
                        }
                    }
                }
            }
        }
    }
}
