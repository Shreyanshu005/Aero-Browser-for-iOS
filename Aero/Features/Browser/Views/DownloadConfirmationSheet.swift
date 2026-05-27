import SwiftUI

struct DownloadConfirmationSheet: View {
    let pendingDownload: PendingDownload
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("File", value: pendingDownload.displayFilename)
                    LabeledContent("From", value: pendingDownload.sourceHost)
                    if let formattedSize = pendingDownload.formattedSize {
                        LabeledContent("Size", value: formattedSize)
                    }
                    if let mimeType = pendingDownload.mimeType {
                        LabeledContent("Type", value: mimeType)
                    }
                }

                Section {
                    Button {
                        viewModel.confirmPendingDownload(id: pendingDownload.id)
                        dismiss()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                    }

                    Button(role: .cancel) {
                        viewModel.cancelPendingDownload(id: pendingDownload.id)
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Download File?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
