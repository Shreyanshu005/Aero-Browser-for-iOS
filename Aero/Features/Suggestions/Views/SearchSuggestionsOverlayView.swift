import SwiftUI

struct SearchSuggestionsOverlayView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            backdrop

            if hasSuggestionContent {
                suggestionsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
    }

    private var backdrop: some View {
        Rectangle()
            .fill(Color.clear)
            .background(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground).opacity(0.14),
                        Color(UIColor.systemBackground).opacity(0.44)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.dismissSearchPresentation()
            }
    }

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ViewThatFits(in: .vertical) {
                suggestionGroups

                ScrollView {
                    suggestionGroups
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: 430, alignment: .bottom)
            .padding(.horizontal, AeroSpacing.md)
            .padding(.top, AeroSpacing.md)
            .padding(.bottom, AeroSpacing.lg)
        }
    }

    @ViewBuilder
    private var suggestionGroups: some View {
        VStack(spacing: AeroSpacing.sm) {
            if !viewModel.suggestions.isEmpty {
                SuggestionsDropdown(
                    suggestions: viewModel.suggestions,
                    onSelect: viewModel.selectSuggestion
                )
            }

            if !viewModel.searchSuggestions.isEmpty {
                SearchSuggestionsListView(viewModel: viewModel)
            }
        }
    }

    private var hasSuggestionContent: Bool {
        !viewModel.suggestions.isEmpty || !viewModel.searchSuggestions.isEmpty
    }
}
