import Foundation
import Testing
@testable import Aero

struct AgentExtractionRecipeTests {

    @Test func extractsLinksAndHeadingsFromObservedElements() {
        let input = AgentExtractionInput(
            url: URL(string: "https://example.com/shop/index.html")!,
            elements: [
                AgentExtractionElement(
                    tagName: "main",
                    children: [
                        AgentExtractionElement(tagName: "h1", text: "Weekly Deals"),
                        AgentExtractionElement(
                            tagName: "div",
                            text: "Featured Picks",
                            attributes: ["role": "heading", "aria-level": "2"]
                        ),
                        AgentExtractionElement(
                            tagName: "a",
                            text: "About Aero",
                            attributes: ["href": "/about", "rel": "help"]
                        ),
                        AgentExtractionElement(
                            tagName: "a",
                            text: "Duplicate about",
                            attributes: ["href": "/about"]
                        ),
                    ]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.links, .headings], from: input)

        #expect(bundle.links.count == 1)
        #expect(bundle.links.first?.text == "About Aero")
        #expect(bundle.links.first?.url.absoluteString == "https://example.com/about")
        #expect(bundle.headings.map(\.text) == ["Weekly Deals", "Featured Picks"])
        #expect(bundle.headings.map(\.level) == [1, 2])
    }

    @Test func extractsPricesFromVisibleText() {
        let input = AgentExtractionInput(visibleText: "Limited offer: $49.99 today, 59.99 USD tomorrow.")

        let bundle = AgentExtractionService().extract([.prices], from: input)

        #expect(bundle.prices.map(\.text) == ["$49.99", "59.99 USD"])
        #expect(bundle.prices.first?.currency == "USD")
        #expect(bundle.prices.first?.amount == Decimal(string: "49.99"))
    }

    @Test func extractsProductCardsWithPriceLinkAndImage() {
        let input = AgentExtractionInput(
            url: URL(string: "https://shop.example/store")!,
            elements: [
                AgentExtractionElement(
                    id: "card-1",
                    tagName: "div",
                    attributes: ["class": "product-card"],
                    children: [
                        AgentExtractionElement(tagName: "h2", text: "Aero Stand"),
                        AgentExtractionElement(tagName: "span", text: "$129.99", attributes: ["class": "price"]),
                        AgentExtractionElement(tagName: "a", text: "View item", attributes: ["href": "/products/aero-stand"]),
                        AgentExtractionElement(tagName: "img", attributes: ["src": "/images/aero-stand.png"]),
                    ]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.productCards], from: input)

        #expect(bundle.productCards.count == 1)
        #expect(bundle.productCards.first?.title == "Aero Stand")
        #expect(bundle.productCards.first?.price?.text == "$129.99")
        #expect(bundle.productCards.first?.url?.absoluteString == "https://shop.example/products/aero-stand")
        #expect(bundle.productCards.first?.imageURL?.absoluteString == "https://shop.example/images/aero-stand.png")
    }

    @Test func extractsSocialPostShape() {
        let input = AgentExtractionInput(
            url: URL(string: "https://social.example/feed")!,
            elements: [
                AgentExtractionElement(
                    tagName: "article",
                    attributes: ["class": "post"],
                    children: [
                        AgentExtractionElement(tagName: "span", text: "Riya", attributes: ["class": "author"]),
                        AgentExtractionElement(tagName: "p", text: "Aero shipped a cleaner tab switcher today.", attributes: ["class": "post-text"]),
                        AgentExtractionElement(tagName: "time", attributes: ["datetime": "2026-05-28T10:00:00Z"]),
                        AgentExtractionElement(tagName: "a", attributes: ["class": "permalink", "href": "/posts/1"]),
                    ]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.posts], from: input)

        #expect(bundle.posts.count == 1)
        #expect(bundle.posts.first?.author == "Riya")
        #expect(bundle.posts.first?.body == "Aero shipped a cleaner tab switcher today.")
        #expect(bundle.posts.first?.timestamp == "2026-05-28T10:00:00Z")
        #expect(bundle.posts.first?.url?.absoluteString == "https://social.example/posts/1")
    }

    @Test func extractsNativeTables() {
        let input = AgentExtractionInput(
            elements: [
                AgentExtractionElement(
                    tagName: "table",
                    children: [
                        AgentExtractionElement(tagName: "caption", text: "Plan Comparison"),
                        AgentExtractionElement(
                            tagName: "tr",
                            children: [
                                AgentExtractionElement(tagName: "th", text: "Plan"),
                                AgentExtractionElement(tagName: "th", text: "Price"),
                            ]
                        ),
                        AgentExtractionElement(
                            tagName: "tr",
                            children: [
                                AgentExtractionElement(tagName: "td", text: "Basic"),
                                AgentExtractionElement(tagName: "td", text: "$9.99"),
                            ]
                        ),
                    ]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.tables], from: input)

        #expect(bundle.tables.count == 1)
        #expect(bundle.tables.first?.caption == "Plan Comparison")
        #expect(bundle.tables.first?.headers == ["Plan", "Price"])
        #expect(bundle.tables.first?.rows == [["Basic", "$9.99"]])
    }

    @Test func extractsSearchResultsFromResultContainers() {
        let input = AgentExtractionInput(
            url: URL(string: "https://search.example/search?q=aero")!,
            title: "Search results for aero",
            elements: [
                AgentExtractionElement(
                    tagName: "div",
                    attributes: ["class": "search-result"],
                    children: [
                        AgentExtractionElement(
                            tagName: "a",
                            text: "Aero Browser",
                            attributes: ["href": "https://aero.example/"]
                        ),
                        AgentExtractionElement(
                            tagName: "p",
                            text: "A fast browser for focused work.",
                            attributes: ["class": "snippet"]
                        ),
                    ]
                ),
            ]
        )

        let bundle = AgentExtractionService().extract([.searchResults], from: input)

        #expect(bundle.searchResults.count == 1)
        #expect(bundle.searchResults.first?.title == "Aero Browser")
        #expect(bundle.searchResults.first?.url.absoluteString == "https://aero.example/")
        #expect(bundle.searchResults.first?.snippet == "A fast browser for focused work.")
    }

    @Test func serviceOnlyRunsRequestedRecipes() {
        let input = AgentExtractionInput(
            url: URL(string: "https://example.com")!,
            elements: [
                AgentExtractionElement(tagName: "h1", text: "Heading"),
                AgentExtractionElement(tagName: "a", text: "Link", attributes: ["href": "https://example.com/link"]),
            ]
        )

        let bundle = AgentExtractionService().extract([.links], from: input)

        #expect(bundle.links.count == 1)
        #expect(bundle.headings.isEmpty)
        #expect(bundle.prices.isEmpty)
    }
}
