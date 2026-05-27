import Foundation

struct LinkActionRequest: Identifiable, Equatable {
    let id: UUID
    let url: URL

    init?(id: UUID = UUID(), url: URL?) {
        guard let url,
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }

        self.id = id
        self.url = url
    }

    var displayHost: String {
        url.displayHost ?? url.host ?? "Link"
    }
}
