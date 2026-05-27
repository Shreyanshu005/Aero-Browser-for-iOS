






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
                        .accessibilityIdentifier("browser.settings.contentBlocker")

                    Button("Clear History", role: .destructive) {
                        viewModel.historyStore.clearHistory()
                    }

                    Button("Clear Cookies & Data", role: .destructive) {
                        let dataStore = WKWebsiteDataStore.default()
                        let types = WKWebsiteDataStore.allWebsiteDataTypes()
                        dataStore.fetchDataRecords(ofTypes: types) { records in
                            dataStore.removeData(ofTypes: types, for: records) {}
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Engine", value: "WebKit")
                }
            }
            .accessibilityIdentifier("browser.settings.list")
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("browser.settings.done")
                }
            }
        }
        .accessibilityIdentifier("browser.settings.sheet")
    }
}
