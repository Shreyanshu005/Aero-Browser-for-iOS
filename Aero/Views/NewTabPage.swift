






import SwiftUI

struct NewTabPage: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AeroSpacing.xxl) {
                    Spacer().frame(height: 32)
                    favoritesGrid
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, AeroSpacing.xl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    private var favoritesGrid: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.lg) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76, maximum: 90), spacing: AeroSpacing.lg)],
                spacing: AeroSpacing.xl
            ) {
                ForEach(viewModel.favoritesStore.favorites) { fav in
                    Button {
                        viewModel.tabManager.loadInActiveTab(url: fav.url)
                    } label: {
                        VStack(spacing: AeroSpacing.sm) {

                            AsyncImage(url: fav.url.faviconURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    fallbackIcon(fav)
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    fallbackIcon(fav)
                                }
                            }
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text(fav.title)
                                .font(.caption2)
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    @ViewBuilder
    private func fallbackIcon(_ fav: FavoriteItem) -> some View {
        Text(fav.displayInitial)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color(UIColor.secondaryLabel))
            .frame(width: 52, height: 52)
            .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
