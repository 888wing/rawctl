//
//  SmartCollectionTests.swift
//  rawctlTests
//
//  Tests for SmartCollection model
//

import Foundation
import Testing
@testable import rawctl

struct SmartCollectionTests {

    @Test func smartCollectionInitializesCorrectly() async throws {
        let collection = SmartCollection(
            name: "5 Stars",
            icon: "star.fill",
            rules: [FilterRule(field: .rating, operation: .equals, value: "5")]
        )

        #expect(collection.name == "5 Stars")
        #expect(collection.rules.count == 1)
    }

    @Test func filterRuleMatchesRating() async throws {
        let rule = FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4")
        let recipe = EditRecipe()
        var ratedRecipe = EditRecipe()
        ratedRecipe.rating = 4

        #expect(rule.matches(recipe: recipe) == false)
        #expect(rule.matches(recipe: ratedRecipe) == true)
    }

    @Test func filterRuleMatchesFlag() async throws {
        let rule = FilterRule(field: .flag, operation: .equals, value: "pick")
        var recipe = EditRecipe()
        recipe.flag = .pick

        #expect(rule.matches(recipe: recipe) == true)

        recipe.flag = .reject
        #expect(rule.matches(recipe: recipe) == false)
    }

    @Test func multipleRulesWithAndLogic() async throws {
        let collection = SmartCollection(
            name: "Best Picks",
            icon: "star.fill",
            rules: [
                FilterRule(field: .rating, operation: .greaterThanOrEqual, value: "4"),
                FilterRule(field: .flag, operation: .equals, value: "pick")
            ],
            ruleLogic: .and
        )

        var recipe = EditRecipe()
        recipe.rating = 5
        recipe.flag = .pick

        #expect(collection.matches(recipe: recipe) == true)

        recipe.flag = .none
        #expect(collection.matches(recipe: recipe) == false)
    }
}
