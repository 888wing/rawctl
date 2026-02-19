//
//  ExportUtilities.swift
//  rawctl
//
//  Shared export utilities for folder organization
//

import Foundation
import ImageIO

/// Shared export utilities
enum ExportUtilities {
    enum JPEGWriteError: LocalizedError {
        case cannotCreateDestination
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .cannotCreateDestination:
                return "Cannot create output file"
            case .writeFailed:
                return "Failed to write file"
            }
        }
    }

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

    /// Write a CGImage as JPEG with the provided quality and profile.
    static func writeJPEG(
        _ image: CGImage,
        to url: URL,
        quality: Int,
        profileName: String = "sRGB"
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            throw JPEGWriteError.cannotCreateDestination
        }

        let normalizedQuality = min(max(quality, 0), 100)
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(normalizedQuality) / 100.0,
            kCGImagePropertyProfileName: profileName as CFString
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw JPEGWriteError.writeFailed
        }
    }
}
