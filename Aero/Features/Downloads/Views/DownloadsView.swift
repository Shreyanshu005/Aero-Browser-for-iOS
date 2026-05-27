
import SwiftUI
import UIKit

struct DownloadsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDownload: DownloadItem?
    @State private var showActions = false

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
                                            if let msg = item.errorMessage, !msg.isEmpty {
                                                Text(msg)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard item.state == .completed, item.localURL != nil else { return }
                                selectedDownload = item
                                showActions = true
                            }
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            .confirmationDialog("Download", isPresented: $showActions, titleVisibility: .visible) {
                if let url = selectedDownload?.localURL {
                    Button("Open") { openFile(url) }
                    Button("Share…") { shareFile(url) }
                }
            }
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

    private func openFile(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func shareFile(_ url: URL) {
        SharePresenter.present(items: [url])
    }
}
