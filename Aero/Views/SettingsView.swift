






import SwiftUI
import WebKit

struct SettingsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Search Engine") {
                    ForEach(SearchEngine.allCases, id: \.self) { engine in
                        Button {
                            viewModel.searchEngine = engine
                        } label: {
                            HStack {
                                Text(engine.rawValue)
                                    .foregroundStyle(Color(UIColor.label))
                                Spacer()
                                if viewModel.searchEngine == engine {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color(UIColor.label))
                                }
                            }
                        }
                    }
                }

                Section("Privacy") {
                    Toggle("Content Blocker", isOn: $viewModel.contentBlockerEnabled)

                    Button("Clear History", role: .destructive) {
                        viewModel.historyStore.clearHistory()
                    }

                    Button("Clear Cookies & Data", role: .destructive) {
                        Task {
                            await PrivacyService.clearAllWebsiteData()
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Engine", value: "WebKit")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
