import Foundation

struct AgentExtractionService {
    var recipes: [AgentExtractionRecipe]

    init(recipes: [AgentExtractionRecipe] = AgentExtractionRecipes.all) {
        self.recipes = recipes
    }

    func extract(
        _ kinds: Set<AgentExtractionKind> = Set(AgentExtractionKind.allCases),
        from input: AgentExtractionInput
    ) -> AgentExtractionBundle {
        var bundle = AgentExtractionBundle()

        for recipe in recipes where kinds.contains(recipe.kind) {
            bundle.merge(recipe.extract(from: input))
        }

        return bundle
    }
}
