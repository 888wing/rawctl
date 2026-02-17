//
//  SmartCollection.swift
//  rawctl
//
//  Dynamic collection based on filter rules
//

import Foundation

/// Field to filter on
enum FilterField: String, Codable, CaseIterable {
    case rating
    case flag
    case colorLabel
    case hasEdits
    case isRAW
    case tag
    case captureDate

    var displayName: String {
        switch self {
        case .rating: return "Rating"
        case .flag: return "Flag"
        case .colorLabel: return "Color Label"
        case .hasEdits: return "Has Edits"
        case .isRAW: return "Is RAW"
        case .tag: return "Tag"
        case .captureDate: return "Capture Date"
        }
    }
}

/// Filter operation type
enum FilterOperation: String, Codable, CaseIterable {
    case equals
    case notEquals
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case contains
    case notContains

    var displayName: String {
        switch self {
        case .equals: return "is"
        case .notEquals: return "is not"
        case .greaterThan: return ">"
        case .greaterThanOrEqual: return ">="
        case .lessThan: return "<"
        case .lessThanOrEqual: return "<="
        case .contains: return "contains"
        case .notContains: return "doesn't contain"
        }
    }
}

/// Single filter rule
struct FilterRule: Codable, Equatable, Identifiable {
    let id: UUID
    var field: FilterField
    var operation: FilterOperation
    var value: String

    init(id: UUID = UUID(), field: FilterField, operation: FilterOperation, value: String) {
        self.id = id
        self.field = field
        self.operation = operation
        self.value = value
    }

    /// Check if a recipe matches this rule
    func matches(recipe: EditRecipe, asset: PhotoAsset? = nil) -> Bool {
        switch field {
        case .rating:
            guard let targetRating = Int(value) else { return false }
            return compareNumeric(recipe.rating, to: targetRating)

        case .flag:
            let recipeFlag = recipe.flag.rawValue
            switch operation {
            case .equals: return recipeFlag == value
            case .notEquals: return recipeFlag != value
            default: return false
            }

        case .colorLabel:
            let recipeColor = recipe.colorLabel.rawValue
            switch operation {
            case .equals: return recipeColor == value
            case .notEquals: return recipeColor != value
            default: return false
            }

        case .hasEdits:
            let hasEdits = recipe.hasEdits
            let targetValue = value.lowercased() == "true"
            switch operation {
            case .equals: return hasEdits == targetValue
            case .notEquals: return hasEdits != targetValue
            default: return false
            }

        case .isRAW:
            guard let asset = asset else { return false }
            let isRAW = asset.isRAW
            let targetValue = value.lowercased() == "true"
            switch operation {
            case .equals: return isRAW == targetValue
            case .notEquals: return isRAW != targetValue
            default: return false
            }

        case .tag:
            let tags = recipe.tags.joined(separator: ",").lowercased()
            let searchValue = value.lowercased()
            switch operation {
            case .contains: return tags.contains(searchValue)
            case .notContains: return !tags.contains(searchValue)
            case .equals: return recipe.tags.contains(where: { $0.lowercased() == searchValue })
            default: return false
            }

        case .captureDate:
            // Date filtering would need asset metadata
            return true
        }
    }

    private func compareNumeric(_ value: Int, to target: Int) -> Bool {
        switch operation {
        case .equals: return value == target
        case .notEquals: return value != target
        case .greaterThan: return value > target
        case .greaterThanOrEqual: return value >= target
        case .lessThan: return value < target
        case .lessThanOrEqual: return value <= target
        default: return false
        }
    }
}

/// Logic for combining multiple rules
enum RuleLogic: String, Codable {
    case and  // All rules must match
    case or   // Any rule matches
}

/// A smart collection with dynamic filtering
struct SmartCollection: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var rules: [FilterRule]
    var ruleLogic: RuleLogic
    var sortOrder: AppState.SortCriteria
    var isBuiltIn: Bool  // System collections can't be deleted

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        rules: [FilterRule] = [],
        ruleLogic: RuleLogic = .and,
        sortOrder: AppState.SortCriteria = .filename,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.rules = rules
        self.ruleLogic = ruleLogic
        self.sortOrder = sortOrder
        self.isBuiltIn = isBuiltIn
    }

    /// Check if a recipe matches all/any rules based on logic
    func matches(recipe: EditRecipe, asset: PhotoAsset? = nil) -> Bool {
        guard !rules.isEmpty else { return true }

        switch ruleLogic {
        case .and:
            return rules.allSatisfy { $0.matches(recipe: recipe, asset: asset) }
        case .or:
            return rules.contains { $0.matches(recipe: recipe, asset: asset) }
        }
    }

    /// Filter assets based on rules
    func filter(assets: [PhotoAsset], recipes: [UUID: EditRecipe]) -> [PhotoAsset] {
        assets.filter { asset in
            let recipe = recipes[asset.id] ?? EditRecipe()
            return matches(recipe: recipe, asset: asset)
        }
    }

    // MARK: - Built-in Collections

    private static let fiveStarsId = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    private static let picksId = UUID(uuidString: "00000000-0000-0000-0000-000000000502")!
    private static let rejectsId = UUID(uuidString: "00000000-0000-0000-0000-000000000503")!
    private static let unratedId = UUID(uuidString: "00000000-0000-0000-0000-000000000504")!
    private static let editedId = UUID(uuidString: "00000000-0000-0000-0000-000000000505")!

    static let fiveStars = SmartCollection(
        id: fiveStarsId,
        name: "5 Stars",
        icon: "star.fill",
        rules: [FilterRule(field: .rating, operation: .equals, value: "5")],
        isBuiltIn: true
    )

    static let picks = SmartCollection(
        id: picksId,
        name: "Picks",
        icon: "flag.fill",
        rules: [FilterRule(field: .flag, operation: .equals, value: "pick")],
        isBuiltIn: true
    )

    static let rejects = SmartCollection(
        id: rejectsId,
        name: "Rejects",
        icon: "xmark.circle.fill",
        rules: [FilterRule(field: .flag, operation: .equals, value: "reject")],
        isBuiltIn: true
    )

    static let unrated = SmartCollection(
        id: unratedId,
        name: "Unrated",
        icon: "star.slash",
        rules: [FilterRule(field: .rating, operation: .equals, value: "0")],
        isBuiltIn: true
    )

    static let edited = SmartCollection(
        id: editedId,
        name: "Edited",
        icon: "slider.horizontal.3",
        rules: [FilterRule(field: .hasEdits, operation: .equals, value: "true")],
        isBuiltIn: true
    )
}
