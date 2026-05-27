import SwiftUI
import UIKit
import QuickLook

struct DownloadsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewFile: PresentedDownloadFile?
    @State private var shareFile: PresentedDownloadFile?
    @State private var exportFile: PresentedDownloadFile?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.downloadManager.downloads.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "arrow.down.circle", description: Text("Files you download will appear here"))
                } else {
                    List {
                        ForEach(viewModel.downloadManager.downloads) { item in
                            downloadRow(item)
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
            .sheet(item: $previewFile) { file in
                DownloadPreview(url: file.url)
            }
            .sheet(item: $shareFile) { file in
                ActivityView(activityItems: [file.url])
            }
            .sheet(item: $exportFile) { file in
                DocumentExporter(url: file.url)
            }
        }
    }

    @ViewBuilder
    private func downloadRow(_ item: DownloadItem) -> some View {
        HStack {
            Button {
                if let localURL = item.localURL, item.isFileAvailable {
                    previewFile = PresentedDownloadFile(url: localURL)
                }
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.filename)
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(1)

                        statusView(for: item)
                    }
                } icon: {
                    Image(systemName: iconName(for: item))
                }
            }
            .buttonStyle(.plain)
            .disabled(!item.isFileAvailable)

            Spacer()

            Menu {
                menuActions(for: item)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .frame(width: 36, height: 36)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            swipeActions(for: item)
        }
    }

    @ViewBuilder
    private func statusView(for item: DownloadItem) -> some View {
        switch item.state {
        case .pending:
            Text("Waiting")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .downloading:
            ProgressView(value: item.progress)
            Text(item.formattedProgress)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .completed:
            Text(item.isFileAvailable ? "Completed" : "File unavailable")
                .font(.caption)
                .foregroundStyle(item.isFileAvailable ? .green : .orange)
        case .failed:
            Text(item.errorMessage ?? "Failed")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func menuActions(for item: DownloadItem) -> some View {
        if let localURL = item.localURL, item.isFileAvailable {
            Button {
                previewFile = PresentedDownloadFile(url: localURL)
            } label: {
                Label("Open", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                shareFile = PresentedDownloadFile(url: localURL)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                exportFile = PresentedDownloadFile(url: localURL)
            } label: {
                Label("Save to Files", systemImage: "folder")
            }
        }

        if item.state == .downloading {
            Button {
                viewModel.downloadManager.cancelDownload(id: item.id)
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        }

        if item.state == .failed || item.state == .cancelled {
            Button {
                viewModel.downloadManager.retryDownload(id: item.id)
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }

        Button(role: .destructive) {
            viewModel.downloadManager.deleteDownload(id: item.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func swipeActions(for item: DownloadItem) -> some View {
        if item.state == .downloading {
            Button(role: .destructive) {
                viewModel.downloadManager.cancelDownload(id: item.id)
            } label: {
                Label("Cancel", systemImage: "xmark.circle")
            }
        } else {
            Button(role: .destructive) {
                viewModel.downloadManager.deleteDownload(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func iconName(for item: DownloadItem) -> String {
        switch item.state {
        case .completed:
            return item.isFileAvailable ? "doc.fill" : "exclamationmark.triangle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .pending, .downloading:
            return "arrow.down.circle.fill"
        }
    }
}

private struct PresentedDownloadFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct DocumentExporter: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

private struct DownloadPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
