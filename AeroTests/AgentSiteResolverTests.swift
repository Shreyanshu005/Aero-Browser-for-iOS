import Foundation
import Testing
@testable import Aero

struct AgentSiteResolverTests {
    @Test func elonXTaskRoutesToElonProfile() {
        let resolution = AgentSiteResolver().resolve("latest post by Elon on X")

        #expect(resolution.kind == .xProfile)
        #expect(resolution.url.absoluteString == "https://x.com/elonmusk")
        #expect(resolution.query == "Elon Musk")
    }

    @Test func xTaskWithoutKnownProfileRoutesToXSearch() {
        let resolution = AgentSiteResolver().resolve("latest post by OpenAI on X")

        #expect(resolution.kind == .xSearch)
        #expect(resolution.url.host == "x.com")
        #expect(resolution.url.path == "/search")
        #expect(queryValue("q", in: resolution.url) == "OpenAI")
        #expect(resolution.query == "OpenAI")
    }

    @Test func flipkartHintRoutesToFlipkartProductSearch() {
        let resolution = AgentSiteResolver().resolve("find iPhone 15 price on Flipkart")

        #expect(resolution.kind == .flipkartSearch)
        #expect(resolution.url.host == "www.flipkart.com")
        #expect(resolution.url.path == "/search")
        #expect(queryValue("q", in: resolution.url) == "iPhone 15")
        #expect(resolution.query == "iPhone 15")
    }

    @Test func amazonHintRoutesToAmazonProductSearch() {
        let resolution = AgentSiteResolver().resolve("buy iPad case on Amazon")

        #expect(resolution.kind == .amazonSearch)
        #expect(resolution.url.host == "www.amazon.com")
        #expect(resolution.url.path == "/s")
        #expect(queryValue("k", in: resolution.url) == "iPad case")
        #expect(resolution.query == "iPad case")
    }

    @Test func genericShoppingIntentUsesConfiguredSearchEngine() {
        let resolution = AgentSiteResolver().resolve("find iPhone price", searchEngine: .duckDuckGo)

        #expect(resolution.kind == .shoppingSearch)
        #expect(resolution.url.host == "duckduckgo.com")
        #expect(queryValue("q", in: resolution.url) == "iPhone")
        #expect(resolution.query == "iPhone")
    }

    @Test func genericTaskFallsBackToConfiguredSearchEngine() {
        let resolution = AgentSiteResolver().resolve("best browser privacy settings", searchEngine: .bing)

        #expect(resolution.kind == .webSearch)
        #expect(resolution.url.host == "www.bing.com")
        #expect(queryValue("q", in: resolution.url) == "best browser privacy settings")
        #expect(resolution.query == "best browser privacy settings")
    }

    @Test func directURLUsesExistingURLClassification() {
        let resolution = AgentSiteResolver().resolve("example.com")

        #expect(resolution.kind == .directURL)
        #expect(resolution.url.absoluteString == "https://example.com")
        #expect(resolution.query == "example.com")
    }

    @Test func iphoneXPriceDoesNotTriggerXRoute() {
        let resolution = AgentSiteResolver().resolve("iPhone X price")

        #expect(resolution.kind == .shoppingSearch)
        #expect(resolution.url.host == "www.google.com")
        #expect(resolution.query == "iPhone X")
    }
}

private func queryValue(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first { $0.name == name }?
        .value
}
