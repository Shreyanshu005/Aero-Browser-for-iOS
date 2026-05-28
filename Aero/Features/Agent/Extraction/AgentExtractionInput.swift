import Foundation

struct AgentExtractionInput: Equatable, Codable {
    var url: URL?
    var title: String?
    var visibleText: String
    var elements: [AgentExtractionElement]

    init(
        url: URL? = nil,
        title: String? = nil,
        visibleText: String = "",
        elements: [AgentExtractionElement] = []
    ) {
        self.url = url
        self.title = title
        self.visibleText = visibleText
        self.elements = elements
    }
}
struct AgentExtractionElement: Equatable, Codable {
    var id: String?
    var tagName: String
    var text: String
    var attributes: [String: String]
    var children: [AgentExtractionElement]

    init(
        id: String? = nil,
        tagName: String,
        text: String = "",
        attributes: [String: String] = [:],
        children: [AgentExtractionElement] = []
    ) {
        self.id = id
        self.tagName = tagName
        self.text = text
        self.attributes = attributes
        self.children = children
    }
}
