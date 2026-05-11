






import SwiftUI
import WebKit

struct ReaderModeView: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var readerContent: String = ""
    @State private var readerTitle: String = ""
    @State private var isLoading = true
    @State private var fontSize: CGFloat = 18
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AeroColor.backgroundPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(AeroColor.accentCyan)
                } else if readerContent.isEmpty {
                    unavailableState
                } else {
                    readerBody
                }
            }
            .navigationTitle("Reader")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AeroColor.accentCyan)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { fontSize = max(14, fontSize - 2) } label: {
                            Label("Smaller Text", systemImage: "textformat.size.smaller")
                        }
                        Button { fontSize = min(28, fontSize + 2) } label: {
                            Label("Larger Text", systemImage: "textformat.size.larger")
                        }
                    } label: {
                        Image(systemName: "textformat.size")
                            .foregroundStyle(AeroColor.accentCyan)
                    }
                }
            }
        }
        .onAppear { extractContent() }
    }

    private var readerBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AeroSpacing.lg) {
                Text(readerTitle)
                    .font(.system(size: fontSize + 6, weight: .bold, design: .serif))
                    .foregroundStyle(AeroColor.textPrimary)

                if let host = viewModel.activeTab?.url?.displayHost {
                    Text(host)
                        .font(AeroFont.caption)
                        .foregroundStyle(AeroColor.accentCyan)
                }

                Divider()
                    .background(AeroColor.surfaceBorder)

                Text(readerContent)
                    .font(.system(size: fontSize, weight: .regular, design: .serif))
                    .foregroundStyle(AeroColor.textPrimary.opacity(0.9))
                    .lineSpacing(fontSize * 0.5)
            }
            .padding(.horizontal, AeroSpacing.xl)
            .padding(.vertical, AeroSpacing.xxl)
        }
    }

    private var unavailableState: some View {
        VStack(spacing: AeroSpacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AeroColor.textTertiary)
            Text("Reader Not Available")
                .font(AeroFont.headline)
                .foregroundStyle(AeroColor.textSecondary)
            Text("This page doesn't have readable content")
                .font(AeroFont.caption)
                .foregroundStyle(AeroColor.textTertiary)
        }
    }

    private func extractContent() {
        guard let webView = viewModel.activeTab?.webView else {
            isLoading = false
            return
        }

        let js = """
        (function() {
            var title = document.title || '';
            var article = document.querySelector('article');
            var content = '';
            if (article) {
                content = article.innerText;
            } else {
                var main = document.querySelector('main') || document.body;
                var paragraphs = main.querySelectorAll('p');
                var texts = [];
                for (var i = 0; i < paragraphs.length; i++) {
                    var text = paragraphs[i].innerText.trim();
                    if (text.length > 40) texts.push(text);
                }
                content = texts.join('\\n\\n');
            }
            return JSON.stringify({title: title, content: content});
        })()
        """

        webView.evaluateJavaScript(js) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8),
                      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                    return
                }
                readerTitle = parsed["title"] ?? ""
                readerContent = parsed["content"] ?? ""
            }
        }
    }
}
