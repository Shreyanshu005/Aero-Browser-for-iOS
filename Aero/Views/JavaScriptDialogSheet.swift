import SwiftUI

struct JavaScriptDialogSheet: View {
    let request: JavaScriptDialogRequest
    @Bindable var viewModel: BrowserViewModel

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isPromptFocused: Bool
    @State private var promptText = ""
    @State private var didInitializePrompt = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(request.message.isEmpty ? " " : request.message)
                        .textSelection(.enabled)
                } header: {
                    Text("From \(request.sourceHost)")
                }

                if request.isPrompt {
                    Section {
                        TextField("Response", text: $promptText, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($isPromptFocused)
                            .submitLabel(.done)
                            .onSubmit(accept)
                    }
                }

                Section {
                    actionButtons
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
        .onAppear(perform: initializePromptIfNeeded)
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch request.kind {
        case .alert:
            Button(action: accept) {
                Label("OK", systemImage: "checkmark.circle.fill")
            }
        case .confirm:
            Button(role: .cancel, action: cancel) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            Button(action: accept) {
                Label("OK", systemImage: "checkmark.circle.fill")
            }
        case .prompt:
            Button(role: .cancel, action: cancel) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            Button(action: accept) {
                Label("OK", systemImage: "checkmark.circle.fill")
            }
        }
    }

    private var navigationTitle: String {
        switch request.kind {
        case .alert:
            return "Alert"
        case .confirm:
            return "Confirm"
        case .prompt:
            return "Prompt"
        }
    }

    private func initializePromptIfNeeded() {
        guard request.isPrompt, !didInitializePrompt else { return }

        promptText = request.defaultPromptText
        didInitializePrompt = true

        DispatchQueue.main.async {
            isPromptFocused = true
        }
    }

    private func accept() {
        viewModel.acceptJavaScriptDialog(id: request.id, promptText: promptText)
        dismiss()
    }

    private func cancel() {
        viewModel.cancelJavaScriptDialog(id: request.id)
        dismiss()
    }
}
