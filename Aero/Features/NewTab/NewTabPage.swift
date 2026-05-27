






import SwiftUI
import UIKit

struct NewTabPage: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var appeared = false
    @State private var backgroundSettings = NewTabBackgroundSettings.shared

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: AeroSpacing.xxl) {
                    Spacer().frame(height: 80)


                    VStack(spacing: AeroSpacing.sm) {
                        if viewModel.activeTab?.isPrivate == true {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                        }

                        Text(viewModel.activeTab?.isPrivate == true ? "Private" : "Aero")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .accessibilityIdentifier("browser.newTab.title")
                    }
                    .padding(.horizontal, usesCustomBackground ? AeroSpacing.lg : 0)
                    .padding(.vertical, usesCustomBackground ? AeroSpacing.md : 0)
                    .background {
                        if usesCustomBackground {
                            Capsule()
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .shadow(color: textShadowColor, radius: 10, y: 3)
                    .opacity(appeared ? 1 : 0)


                    favoritesGrid

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, AeroSpacing.xl)
            }
            .accessibilityIdentifier("browser.newTab.scrollView")
        }
        .accessibilityIdentifier("browser.newTab.page")
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let backgroundImageURL,
           let image = UIImage(contentsOfFile: backgroundImageURL.path) {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()
            }
            .ignoresSafeArea()

            Color.black
                .opacity(viewModel.activeTab?.isPrivate == true ? 0.58 : 0.38)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.46),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
        }
    }

    private var favoritesGrid: some View {
        VStack(alignment: .leading, spacing: AeroSpacing.lg) {
            Text("Favorites")
                .font(.footnote)
                .foregroundStyle(secondaryTextColor)
                .textCase(.uppercase)
                .accessibilityIdentifier("browser.newTab.favoritesTitle")

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
                                        .tint(primaryTextColor)
                                @unknown default:
                                    fallbackIcon(fav)
                                }
                            }
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .background(iconBackgroundColor, in: RoundedRectangle(cornerRadius: 12))

                            Text(fav.title)
                                .font(.caption2)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(usesCustomBackground ? AeroSpacing.lg : 0)
        .background {
            if usesCustomBackground {
                RoundedRectangle(cornerRadius: AeroRadius.xl)
                    .fill(.ultraThinMaterial)
            }
        }
        .shadow(color: textShadowColor, radius: 12, y: 4)
        .accessibilityIdentifier("browser.newTab.favorites")
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    private var backgroundImageURL: URL? {
        backgroundSettings.imageURL
    }

    private var usesCustomBackground: Bool {
        backgroundImageURL != nil
    }

    private var primaryTextColor: Color {
        usesCustomBackground ? Color.white : Color(UIColor.label)
    }

    private var secondaryTextColor: Color {
        usesCustomBackground ? Color.white.opacity(0.82) : Color(UIColor.secondaryLabel)
    }

    private var iconBackgroundColor: Color {
        usesCustomBackground ? Color.white.opacity(0.18) : Color(UIColor.secondarySystemBackground)
    }

    private var textShadowColor: Color {
        usesCustomBackground ? Color.black.opacity(0.35) : Color.clear
    }

    @ViewBuilder
    private func fallbackIcon(_ fav: FavoriteItem) -> some View {
        Text(fav.displayInitial)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(secondaryTextColor)
            .frame(width: 28, height: 28)
    }
}
