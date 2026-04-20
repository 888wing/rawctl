//
//  SidecarMigrationTests.swift
//  rawctlTests
//
//  Legacy sidecar schema and filename migration coverage.
//

import Foundation
import Testing
@testable import Latent

struct SidecarMigrationTests {
    @Test func legacySchemaWithoutVersionDecodesWithDefaults() throws {
        let data = try makeLegacySidecarData(
            assetFilename: "legacy.jpg",
            exposure: 0.25,
            schemaVersion: nil
        )

        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)
        #expect(decoded.schemaVersion == 1)
        #expect(decoded.edit.exposure == 0.25)
        #expect(decoded.snapshots.isEmpty)
        #expect(decoded.aiEdits.isEmpty)
        #expect(decoded.localNodes == nil)
        #expect(decoded.aiLayers.isEmpty)
    }

    @Test func legacySidecarRoundtripUpgradesToCurrentSchema() throws {
        let data = try makeLegacySidecarData(
            assetFilename: "legacy-roundtrip.jpg",
            exposure: 0.4,
            schemaVersion: 2
        )

        let decodedLegacy = try JSONDecoder().decode(SidecarFile.self, from: data)
        let encoded = try JSONEncoder().encode(decodedLegacy)
        let roundtrip = try JSONDecoder().decode(SidecarFile.self, from: encoded)

        #expect(roundtrip.schemaVersion == SidecarFile.currentSchemaVersion)
        #expect(roundtrip.edit.exposure == decodedLegacy.edit.exposure)
        #expect(roundtrip.snapshots == decodedLegacy.snapshots)
        #expect(roundtrip.aiEdits == decodedLegacy.aiEdits)
        #expect(roundtrip.localNodes == decodedLegacy.localNodes)
        #expect(roundtrip.aiLayers == decodedLegacy.aiLayers)
    }

    @Test func legacyToneCurvePointsWithoutIDsDecodeAndUpgrade() throws {
        let data = try makeLegacySidecarData(
            assetFilename: "legacy-curve.jpg",
            exposure: 0.4,
            schemaVersion: 5,
            toneCurvePoints: [
                (0.0, 0.0),
                (0.25, 0.2),
                (0.5, 0.55),
                (0.75, 0.85),
                (1.0, 1.0)
            ]
        )

        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)
        #expect(decoded.edit.toneCurve.points.count == 5)
        #expect(Set(decoded.edit.toneCurve.points.map(\.id)).count == 5)

        let roundtripData = try JSONEncoder().encode(decoded)
        let roundtripObject = try JSONSerialization.jsonObject(with: roundtripData) as? [String: Any]
        let edit = roundtripObject?["edit"] as? [String: Any]
        let toneCurve = edit?["toneCurve"] as? [String: Any]
        let points = toneCurve?["points"] as? [[String: Any]]

        #expect(points?.allSatisfy { $0["id"] != nil } == true)
    }

    @Test func legacyCropWithoutStraightenAngleDecodesWithDefault() throws {
        let data = try makeLegacySidecarData(
            assetFilename: "legacy-crop.jpg",
            exposure: 0.4,
            schemaVersion: 5,
            cropPayload: [
                "isEnabled": true,
                "aspect": "free",
                "rect": [
                    "x": 0.1,
                    "y": 0.2,
                    "w": 0.7,
                    "h": 0.6
                ],
                "rotationDegrees": 90,
                "flipHorizontal": true
            ]
        )

        let decoded = try JSONDecoder().decode(SidecarFile.self, from: data)
        #expect(decoded.edit.crop.isEnabled)
        #expect(decoded.edit.crop.rotationDegrees == 90)
        #expect(decoded.edit.crop.flipHorizontal)
        #expect(decoded.edit.crop.straightenAngle == 0)
    }

    @Test func saveRecipeOnlyUpgradesLegacySchemaOnWrite() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-migrate-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("upgrade.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        let legacyData = try makeLegacySidecarData(
            assetFilename: assetURL.lastPathComponent,
            exposure: 0.1,
            schemaVersion: 2
        )
        try legacyData.write(to: sidecarURL, options: .atomic)

        var recipe = EditRecipe()
        recipe.exposure = 1.4
        await SidecarService.shared.saveRecipeOnly(recipe, for: assetURL)

        let upgradedData = try Data(contentsOf: sidecarURL)
        let upgraded = try JSONDecoder().decode(SidecarFile.self, from: upgradedData)
        #expect(upgraded.schemaVersion == SidecarFile.currentSchemaVersion)
        #expect(upgraded.edit.exposure == 1.4)
        #expect(upgraded.aiLayers.isEmpty)
    }

    @Test func loadRecipeAndSnapshotsMigratesLegacyFilename() async throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("latent-sidecar-filename-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let assetURL = dir.appendingPathComponent("legacy-name.jpg")
        try Data([0xFF, 0xD8, 0xFF, 0xD9]).write(to: assetURL, options: .atomic)

        let legacyURL = FileSystemService.legacySidecarURL(for: assetURL)
        let newURL = FileSystemService.sidecarURL(for: assetURL)
        let legacyData = try makeLegacySidecarData(
            assetFilename: assetURL.lastPathComponent,
            exposure: 0.66,
            schemaVersion: 5
        )
        try legacyData.write(to: legacyURL, options: .atomic)

        #expect(FileManager.default.fileExists(atPath: legacyURL.path))
        #expect(!FileManager.default.fileExists(atPath: newURL.path))

        let loaded = await SidecarService.shared.loadRecipeAndSnapshots(for: assetURL)
        #expect(loaded != nil)
        #expect(loaded?.0.exposure == 0.66)
        #expect(FileManager.default.fileExists(atPath: newURL.path))
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    private func makeLegacySidecarData(
        assetFilename: String,
        exposure: Double,
        schemaVersion: Int?,
        toneCurvePoints: [(Double, Double)]? = nil,
        cropPayload: [String: Any]? = nil
    ) throws -> Data {
        var edit: [String: Any] = [
            "exposure": exposure
        ]

        if let toneCurvePoints {
            edit["toneCurve"] = [
                "points": toneCurvePoints.map { point in
                    [
                        "x": point.0,
                        "y": point.1
                    ]
                }
            ]
        }

        if let cropPayload {
            edit["crop"] = cropPayload
        }

        var payload: [String: Any] = [
            "asset": [
                "originalFilename": assetFilename,
                "fileSize": 1024,
                "modifiedTime": 0
            ],
            "edit": edit,
            "updatedAt": 1_234_567_890.0
        ]
        if let schemaVersion {
            payload["schemaVersion"] = schemaVersion
        }
        return try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
    }
}
