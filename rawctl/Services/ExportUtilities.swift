//
//  ExportUtilities.swift
//  rawctl
//
//  Shared export utilities for folder organization
//

import Foundation

/// Shared export utilities
enum ExportUtilities {
    /// Determine target folder based on organization mode
    static func determineTargetFolder(
        for asset: PhotoAsset,
        recipe: EditRecipe,
        organization: ExportOrganizationMode,
        base: URL
    ) -> URL {
        switch organization {
        case .flat:
            return base

        case .byRating:
            let rating = recipe.rating
            let folderName = rating > 0 ? "\(rating)-stars" : "unrated"
            return base.appendingPathComponent(folderName)

        case .byDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let folderName = formatter.string(from: asset.creationDate ?? Date())
            return base.appendingPathComponent(folderName)

        case .byColor:
            return base.appendingPathComponent(recipe.colorLabel.displayName)

        case .byFlag:
            switch recipe.flag {
            case .pick: return base.appendingPathComponent("Picks")
            case .reject: return base.appendingPathComponent("Rejects")
            case .none: return base.appendingPathComponent("Unflagged")
            }
        }
    }
}
