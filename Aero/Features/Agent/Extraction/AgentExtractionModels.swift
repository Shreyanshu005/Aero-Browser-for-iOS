import Foundation

enum AgentExtractionKind: String, CaseIterable, Equatable, Hashable, Codable {
    case posts
    case prices
    case productCards
    case links
    case headings
    case tables
    case searchResults
}
struct AgentExtractionSource: Equatable, Codable {
    var elementID: String?
    var tagName: String?
    var confidence: Double

    init(
        elementID: String? = nil,
        tagName: String? = nil,
        confidence: Double
    ) {
        self.elementID = elementID
        self.tagName = tagName
        self.confidence = confidence
    }
}

struct AgentExtractedPost: Equatable, Codable {
    var author: String?
    var body: String
    var timestamp: String?
    var url: URL?
    var source: AgentExtractionSource
}

struct AgentExtractedPrice: Equatable, Codable {
    var text: String
    var currency: String?
    var amount: Decimal?
    var source: AgentExtractionSource
}

struct AgentExtractedProductCard: Equatable, Codable {
    var title: String
    var price: AgentExtractedPrice?
    var url: URL?
    var imageURL: URL?
    var source: AgentExtractionSource
}

struct AgentExtractedLink: Equatable, Codable {
    var text: String
    var url: URL
    var rel: String?
    var source: AgentExtractionSource
}

struct AgentExtractedHeading: Equatable, Codable {
    var level: Int
    var text: String
    var source: AgentExtractionSource
}

struct AgentExtractedTable: Equatable, Codable {
    var caption: String?
    var headers: [String]
    var rows: [[String]]
    var source: AgentExtractionSource
}

struct AgentExtractedSearchResult: Equatable, Codable {
    var title: String
    var url: URL
    var snippet: String?
    var source: AgentExtractionSource
}

enum AgentExtractionResult: Equatable {
    case posts([AgentExtractedPost])
    case prices([AgentExtractedPrice])
    case productCards([AgentExtractedProductCard])
    case links([AgentExtractedLink])
    case headings([AgentExtractedHeading])
    case tables([AgentExtractedTable])
    case searchResults([AgentExtractedSearchResult])

    var kind: AgentExtractionKind {
        switch self {
        case .posts:
            return .posts
        case .prices:
            return .prices
        case .productCards:
            return .productCards
        case .links:
            return .links
        case .headings:
            return .headings
        case .tables:
            return .tables
        case .searchResults:
            return .searchResults
        }
    }
}

struct AgentExtractionBundle: Equatable, Codable {
    var posts: [AgentExtractedPost]
    var prices: [AgentExtractedPrice]
    var productCards: [AgentExtractedProductCard]
    var links: [AgentExtractedLink]
    var headings: [AgentExtractedHeading]
    var tables: [AgentExtractedTable]
    var searchResults: [AgentExtractedSearchResult]

    init(
        posts: [AgentExtractedPost] = [],
        prices: [AgentExtractedPrice] = [],
        productCards: [AgentExtractedProductCard] = [],
        links: [AgentExtractedLink] = [],
        headings: [AgentExtractedHeading] = [],
        tables: [AgentExtractedTable] = [],
        searchResults: [AgentExtractedSearchResult] = []
    ) {
        self.posts = posts
        self.prices = prices
        self.productCards = productCards
        self.links = links
        self.headings = headings
        self.tables = tables
        self.searchResults = searchResults
    }

    mutating func merge(_ result: AgentExtractionResult) {
        switch result {
        case .posts(let items):
            posts.append(contentsOf: items)
        case .prices(let items):
            prices.append(contentsOf: items)
        case .productCards(let items):
            productCards.append(contentsOf: items)
        case .links(let items):
            links.append(contentsOf: items)
        case .headings(let items):
            headings.append(contentsOf: items)
        case .tables(let items):
            tables.append(contentsOf: items)
        case .searchResults(let items):
            searchResults.append(contentsOf: items)
        }
    }
}
