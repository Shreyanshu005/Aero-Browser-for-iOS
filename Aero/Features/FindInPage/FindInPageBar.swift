
import SwiftUI

struct FindInPageBar: View {
    @Bindable var viewModel: BrowserViewModel
    @State private var searchText = ""
    @State private var currentMatch = 0
    @State private var totalMatches = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: AeroSpacing.sm) {

            HStack(spacing: AeroSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(AeroColor.textTertiary)

                TextField("Find in page", text: $searchText)
                    .font(AeroFont.body)
                    .foregroundStyle(AeroColor.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($isFocused)
                    .onSubmit { findNext() }
                    .onChange(of: searchText) { _, newValue in
                        performSearch(newValue)
                    }

                if !searchText.isEmpty {
                    Text("\(currentMatch)/\(totalMatches)")
                        .font(AeroFont.captionSmall)
                        .foregroundStyle(AeroColor.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AeroSpacing.md)
            .padding(.vertical, AeroSpacing.sm)
            .background(AeroColor.backgroundElevated, in: RoundedRectangle(cornerRadius: AeroRadius.sm))

            Button { findPrevious() } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(totalMatches > 0 ? AeroColor.textPrimary : AeroColor.textTertiary)
            }
            .disabled(totalMatches == 0)

            Button { findNext() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(totalMatches > 0 ? AeroColor.textPrimary : AeroColor.textTertiary)
            }
            .disabled(totalMatches == 0)

            Button("Done") {
                clearSearch()
                viewModel.showFindInPage = false
            }
            .font(AeroFont.caption)
            .foregroundStyle(AeroColor.accentCyan)
        }
        .padding(.horizontal, AeroSpacing.md)
        .padding(.vertical, AeroSpacing.sm)
        .background(.thinMaterial)
        .onAppear { isFocused = true }
    }

    private func performSearch(_ query: String) {
        guard let webView = viewModel.activeTab?.webView, !query.isEmpty else {
            totalMatches = 0
            currentMatch = 0
            return
        }

        let js = """
        window.find('\(query.replacingOccurrences(of: "'", with: "\\'"))', false, false, true, false, true, false)
        """
        webView.evaluateJavaScript(js) { _, _ in }

        let countJS = """
        (function() {
            var count = 0;
            var pos = 0;
            var text = document.body.innerText.toLowerCase();
            var query = '\(query.lowercased().replacingOccurrences(of: "'", with: "\\'"))';
            while ((pos = text.indexOf(query, pos)) !== -1) { count++; pos += query.length; }
            return count;
        })()
        """
        webView.evaluateJavaScript(countJS) { result, _ in
            if let count = result as? Int {
                totalMatches = count
                currentMatch = count > 0 ? 1 : 0
            }
        }
    }

    private func findNext() {
        guard let webView = viewModel.activeTab?.webView else { return }
        let js = "window.find('\(searchText.replacingOccurrences(of: "'", with: "\\'"))', false, false, true)"
        webView.evaluateJavaScript(js) { _, _ in
            if currentMatch < totalMatches { currentMatch += 1 }
            else { currentMatch = 1 }
        }
    }

    private func findPrevious() {
        guard let webView = viewModel.activeTab?.webView else { return }
        let js = "window.find('\(searchText.replacingOccurrences(of: "'", with: "\\'"))', false, true, true)"
        webView.evaluateJavaScript(js) { _, _ in
            if currentMatch > 1 { currentMatch -= 1 }
            else { currentMatch = totalMatches }
        }
    }

    private func clearSearch() {
        viewModel.activeTab?.webView?.evaluateJavaScript("window.getSelection().removeAllRanges()") { _, _ in }
        searchText = ""
    }
}
