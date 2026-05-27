import SwiftUI
import UIKit

struct LinkActionsSheet: View {
    let request: LinkActionRequest
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(request.displayHost)
                            .font(.headline)
                            .foregroundStyle(Color(UIColor.label))
                            .lineLimit(1)

                        Text(request.url.absoluteString)
                            .font(.footnote)
                            .foregroundStyle(Color(UIColor.secondaryLabel))
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Link")
                }

                Section {
                    Button {
                        viewModel.openPendingLinkInNewTab(id: request.id)
                        dismiss()
                    } label: {
                        Label("Open in New Tab", systemImage: "plus.square.on.square")
                    }

                    Button {
                        viewModel.openPendingLinkInPrivateTab(id: request.id)
                        dismiss()
                    } label: {
                        Label("Open in Private Tab", systemImage: "eye.slash")
                    }

                    Button {
                        UIPasteboard.general.string = request.url.absoluteString
                        viewModel.dismissPendingLinkActions(id: request.id)
                        dismiss()
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc")
                    }

                    ShareLink(item: request.url) {
                        Label("Share Link", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .cancel) {
                        viewModel.dismissPendingLinkActions(id: request.id)
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Link Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
