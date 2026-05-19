import SwiftUI

struct SearchSuggestionsOverlayView: View {
    @Bindable var viewModel: BrowserViewModel

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                if viewModel.addressBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyView()
                } else if viewModel.searchSuggestions.isEmpty {
                    EmptyView()
                } else {
                    ScrollView {
                        SearchSuggestionsListView(viewModel: viewModel)
                            .padding(.horizontal, AeroSpacing.md)
                            .padding(.top, AeroSpacing.md)
                    }
                    .scrollIndicators(.hidden)
                }

                Spacer(minLength: 0)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onTapGesture {
            viewModel.dismissSearchPresentation()
        }
    }
}
