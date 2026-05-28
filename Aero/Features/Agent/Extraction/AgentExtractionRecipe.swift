import Foundation

protocol AgentExtractionRecipe {
    var kind: AgentExtractionKind { get }

    func extract(from input: AgentExtractionInput) -> AgentExtractionResult
}
