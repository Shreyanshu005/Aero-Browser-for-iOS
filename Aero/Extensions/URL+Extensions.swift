






import Foundation

extension URL {

    var displayHost: String? {
        guard let host = self.host else { return nil }
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }


    var isSecure: Bool {
        self.scheme?.lowercased() == "https"
    }


    var faviconURL: URL? {
        guard let host = self.host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64")
    }


    var shortDisplayString: String {
        displayHost ?? absoluteString
    }


    var isInternalPage: Bool {
        scheme == "about" || scheme == "aero"
    }
}

extension String {

    var looksLikeURL: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.contains(" ") && trimmed.contains(".")
    }
}
