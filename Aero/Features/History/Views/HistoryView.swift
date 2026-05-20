






import SwiftUI

struct HistoryView: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredGroups: [(key: String, items: [HistoryItem])] {
        if searchText.isEmpty {
            return viewModel.historyStore.groupedByDay()
        }
        let results = viewModel.historyStore.search(query: searchText)
        if results.isEmpty { return [] }
        return [("Search Results", results)]
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.historyStore.items.isEmpty {
                    ContentUnavailableView("No History", systemImage: "clock", description: Text("Pages you visit will appear here"))
                } else {
                    List {
                        ForEach(filteredGroups, id: \.key) { group in
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
                    if !viewModel.historyStore.items.isEmpty {
                        Button("Clear", role: .destructive) {
                            viewModel.historyStore.clearHistory()
                        }
                    }
                }
            }
        }
    }
}
