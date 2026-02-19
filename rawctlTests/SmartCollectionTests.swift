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

    @Test func captureDateEqualsRespectsLocalDayBoundaries() async throws {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())
        let query = dateOnlyString(dayStart)

        let inside = makeAsset(metadataDate: dayStart.addingTimeInterval(3600))
        let outside = makeAsset(metadataDate: dayStart.addingTimeInterval(-1))
        let rule = FilterRule(field: .captureDate, operation: .equals, value: query)

        #expect(rule.matches(recipe: EditRecipe(), asset: inside) == true)
        #expect(rule.matches(recipe: EditRecipe(), asset: outside) == false)
    }

    @Test func captureDateComparisonSupportsGreaterAndLessOperations() async throws {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: Date())
        let query = dateOnlyString(referenceDay)
        let older = makeAsset(metadataDate: referenceDay.addingTimeInterval(-3600))
        let newer = makeAsset(metadataDate: referenceDay.addingTimeInterval(48 * 3600))

        let greater = FilterRule(field: .captureDate, operation: .greaterThan, value: query)
        let lessOrEqual = FilterRule(field: .captureDate, operation: .lessThanOrEqual, value: query)

        #expect(greater.matches(recipe: EditRecipe(), asset: older) == false)
        #expect(greater.matches(recipe: EditRecipe(), asset: newer) == true)
        #expect(lessOrEqual.matches(recipe: EditRecipe(), asset: older) == true)
        #expect(lessOrEqual.matches(recipe: EditRecipe(), asset: newer) == false)
    }

    @Test func captureDateFallsBackToCreationDateWhenExifMissing() async throws {
        let calendar = Calendar.current
        let now = Date()
        let recent = makeAsset(metadataDate: nil, creationDate: now, modificationDate: now)
        let oldDate = calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast
        let old = makeAsset(metadataDate: nil, creationDate: oldDate, modificationDate: oldDate)

        let query = dateOnlyString(calendar.startOfDay(for: now))
        let rule = FilterRule(field: .captureDate, operation: .greaterThanOrEqual, value: query)

        #expect(rule.matches(recipe: EditRecipe(), asset: recent) == true)
        #expect(rule.matches(recipe: EditRecipe(), asset: old) == false)
    }

    @Test func captureDateReturnsFalseWhenNoDateDataAvailable() async throws {
        let asset = makeAsset(metadataDate: nil, creationDate: nil, modificationDate: nil)
        let rule = FilterRule(field: .captureDate, operation: .equals, value: "2026-01-01")
        #expect(rule.matches(recipe: EditRecipe(), asset: asset) == false)
    }

    private func makeAsset(
        metadataDate: Date?,
        creationDate: Date? = nil,
        modificationDate: Date? = nil
    ) -> PhotoAsset {
        let url = URL(fileURLWithPath: "/tmp/\(UUID().uuidString).jpg")
        var asset = PhotoAsset(
            url: url,
            fileSize: 100,
            creationDate: creationDate,
            modificationDate: modificationDate,
            fingerprint: UUID().uuidString
        )
        if let metadataDate {
            asset.metadata = ImageMetadata(
                width: nil,
                height: nil,
                cameraMake: nil,
                cameraModel: nil,
                lens: nil,
                iso: nil,
                shutterSpeed: nil,
                aperture: nil,
                focalLength: nil,
                dateTime: metadataDate
            )
        }
        return asset
    }

    private func dateOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
