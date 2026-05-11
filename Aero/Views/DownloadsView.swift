






import SwiftUI

struct DownloadsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.downloadManager.downloads.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Files you download will appear here"))
                } else {
                    List {
                        ForEach(viewModel.downloadManager.downloads) { item in
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.filename)
                                            .lineLimit(1)

                                        if item.state == .downloading {
                                            ProgressView(value: item.progress)
                                            Text(item.formattedProgress)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else if item.state == .completed {
                                            Text("Completed")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        } else if item.state == .failed {
                                            Text("Failed")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                } icon: {
                                    Image(systemName: "doc.fill")
                                }

                                if item.state == .downloading {
                                    Button {
                                        viewModel.downloadManager.cancelDownload(id: item.id)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.downloadManager.downloads.isEmpty {
                        Button("Clear") {
                            viewModel.downloadManager.clearCompleted()
                        }
                    }
                }
            }
        }
    }
}
