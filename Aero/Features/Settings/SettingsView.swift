import SwiftUI
import PhotosUI
import UIKit
import WebKit

struct SettingsView: View {
    @Bindable var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBackgroundItem: PhotosPickerItem?
    @State private var isImportingBackground = false
    @State private var backgroundImportError: String?
    @State private var backgroundSettings = NewTabBackgroundSettings.shared
    @State private var agentProviderSettingsViewModel = AgentProviderSettingsViewModel()

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

                Section("New Tab") {
                    HStack(spacing: AeroSpacing.md) {
                        NewTabBackgroundThumbnail(imageURL: backgroundSettings.imageURL)

                        VStack(alignment: .leading, spacing: AeroSpacing.xxs) {
                            Text("Background Image")
                            Text(backgroundSettings.imageURL == nil ? "Default system background" : "Custom image selected")
                                .font(.footnote)
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                    }
                    .accessibilityIdentifier("browser.settings.newTabBackgroundStatus")

                    PhotosPicker(selection: $selectedBackgroundItem, matching: .images) {
                        Label(
                            backgroundSettings.imageURL == nil ? "Choose Background Image" : "Change Background Image",
                            systemImage: "photo"
                        )
                    }
                    .disabled(isImportingBackground)
                    .accessibilityIdentifier("browser.settings.chooseNewTabBackground")

                    if isImportingBackground {
                        ProgressView("Importing Background")
                            .accessibilityIdentifier("browser.settings.newTabBackgroundImporting")
                    }

                    if backgroundSettings.imageURL != nil {
                        Button(role: .destructive) {
                            backgroundSettings.resetBackgroundImage()
                            backgroundImportError = nil
                        } label: {
                            Label("Remove Background", systemImage: "trash")
                        }
                        .accessibilityIdentifier("browser.settings.removeNewTabBackground")
                    }

                    if let backgroundImportError {
                        Text(backgroundImportError)
                            .font(.footnote)
                            .foregroundStyle(AeroColor.error)
                            .accessibilityIdentifier("browser.settings.newTabBackgroundError")
                    }
                }

                Section("Privacy") {
                    Toggle("Content Blocker", isOn: $viewModel.contentBlockerEnabled)
                        .accessibilityIdentifier("browser.settings.contentBlocker")

                    Button("Clear History", role: .destructive) {
                        viewModel.historyStore.clearHistory()
                    }

                    Button("Clear Cookies & Data", role: .destructive) {
                        Task {
                            await PrivacyService.clearAllWebsiteData()
                        }
                    }
                }

                Section("Agent") {
                    NavigationLink {
                        AgentProviderSettingsView(viewModel: agentProviderSettingsViewModel)
                    } label: {
                        LabeledContent(
                            "Provider",
                            value: agentProviderSettingsViewModel.selectedProviderID.displayName
                        )
                    }
                    .accessibilityIdentifier("browser.settings.agentProvider")
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
        .onChange(of: selectedBackgroundItem) { _, item in
            guard let item else { return }

            Task {
                await importBackgroundImage(from: item)
            }
        }
        .accessibilityIdentifier("browser.settings.sheet")
    }

    @MainActor
    private func importBackgroundImage(from item: PhotosPickerItem) async {
        isImportingBackground = true
        backgroundImportError = nil

        defer {
            isImportingBackground = false
            selectedBackgroundItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw NewTabBackgroundImageStoreError.unsupportedImage
            }

            try backgroundSettings.setBackgroundImage(data: data)
        } catch {
            backgroundImportError = error.localizedDescription
        }
    }
}

private struct NewTabBackgroundThumbnail: View {
    let imageURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AeroRadius.sm)
                .fill(Color(UIColor.secondarySystemBackground))

            if let imageURL,
               let image = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }
        }
        .frame(width: 56, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: AeroRadius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: AeroRadius.sm)
                .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
        }
    }
}
