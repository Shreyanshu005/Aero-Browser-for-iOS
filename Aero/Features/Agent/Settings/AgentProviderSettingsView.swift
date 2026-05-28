import SwiftUI
import UIKit

struct AgentProviderSettingsView: View {
    @Bindable var viewModel: AgentProviderSettingsViewModel

    var body: some View {
        List {
            Section("Provider") {
                Picker("Provider", selection: $viewModel.selectedProviderID) {
                    ForEach(AgentProviderID.allCases) { providerID in
                        Text(providerID.displayName)
                            .tag(providerID)
                    }
                }
                .accessibilityIdentifier("agent.settings.providerPicker")

                LabeledContent("Status", value: statusText)
                    .accessibilityIdentifier("agent.settings.providerStatus")
            }

            if viewModel.selectedProviderID != .appleFoundation {
                Section("Model") {
                    TextField(
                        viewModel.selectedProviderID.defaultModel,
                        text: Binding(
                            get: { viewModel.selectedProviderSettings.model },
                            set: { viewModel.updateModel($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("agent.settings.model")
                }
            }

            if viewModel.selectedProviderID.supportsCustomBaseURL {
                Section("Endpoint") {
                    TextField(
                        viewModel.selectedProviderID.defaultBaseURL ?? "",
                        text: Binding(
                            get: { viewModel.selectedProviderSettings.baseURL ?? "" },
                            set: { viewModel.updateBaseURL($0) }
                        )
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("agent.settings.baseURL")
                }
            }

            if viewModel.selectedProviderID.requiresAccountID {
                Section("Cloudflare") {
                    TextField(
                        "Account ID",
                        text: Binding(
                            get: { viewModel.selectedProviderSettings.accountID ?? "" },
                            set: { viewModel.updateAccountID($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("agent.settings.cloudflareAccountID")
                }
            }

            if viewModel.selectedProviderID.requiresAPIKey {
                Section("API Key") {
                    SecureField("API Key", text: $viewModel.draftAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("agent.settings.apiKey")

                    Button {
                        viewModel.saveDraftAPIKey()
                    } label: {
                        Label("Save API Key", systemImage: "key")
                    }
                    .disabled(viewModel.draftAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("agent.settings.saveAPIKey")

                    if viewModel.selectedProviderHasSavedAPIKey {
                        Button(role: .destructive) {
                            viewModel.deleteSavedAPIKey()
                        } label: {
                            Label("Delete API Key", systemImage: "trash")
                        }
                        .accessibilityIdentifier("agent.settings.deleteAPIKey")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AeroColor.error)
                        .accessibilityIdentifier("agent.settings.error")
                }
            }
        }
        .navigationTitle("Agent Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refreshSavedAPIKeyStatus()
        }
        .accessibilityIdentifier("agent.settings.sheet")
    }

    private var statusText: String {
        let providerID = viewModel.selectedProviderID
        if providerID.requiresAPIKey {
            return viewModel.selectedProviderHasSavedAPIKey ? "API key saved" : "API key required"
        }
        if providerID == .appleFoundation {
            return "Requires iOS 26"
        }
        return "No API key required"
    }
}
