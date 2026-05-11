






import SwiftUI

struct BookmarksView: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var showingAddSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favoritesStore.favorites.isEmpty {
                    ContentUnavailableView("No Bookmarks", systemImage: "bookmark", description: Text("Save your favorite pages here"))
                } else {
                    List {
                        ForEach(viewModel.favoritesStore.favorites) { bookmark in
                            Button {
                                viewModel.tabManager.loadInActiveTab(url: bookmark.url)
                                dismiss()
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title)
                                            .foregroundStyle(Color(UIColor.label))
                                            .lineLimit(1)
                                        Text(bookmark.url.displayHost ?? "")
                                            .font(.caption)
                                            .foregroundStyle(Color(UIColor.secondaryLabel))
                                    }
                                } icon: {
                                    AsyncImage(url: bookmark.url.faviconURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Image(systemName: "globe")
                                    }
                                    .frame(width: 20, height: 20)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.favoritesStore.remove(id: viewModel.favoritesStore.favorites[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookmarkSheet(viewModel: viewModel)
            }
        }
    }
}



struct AddBookmarkSheet: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var title = ""
    @State private var urlString = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("URL", text: $urlString)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBookmark()
                    }
                    .disabled(title.isEmpty || urlString.isEmpty)
                }
            }
            .onAppear {
                if let tab = viewModel.activeTab {
                    title = tab.displayTitle
                    urlString = tab.url?.absoluteString ?? ""
                }
            }
        }
    }

    private func saveBookmark() {
        let input = URLInput.classify(urlString)
        switch input {
        case .url(let url):
            viewModel.favoritesStore.add(title: title, url: url)
        case .search:
            if let url = URL(string: "https://\(urlString)") {
                viewModel.favoritesStore.add(title: title, url: url)
            }
        }
        dismiss()
    }
}
