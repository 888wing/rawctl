//
//  SAMServiceTests.swift
//  rawctlTests
//
//  Tests for SAMModelStatus enum and SAMService graceful-degradation
//  behaviour when the Mobile-SAM Core ML model is not installed.
//
//  The model itself is never bundled in the test target, so all
//  inference paths are exercised via their fallback (nil) code paths.
//

import Foundation
import Testing
import CoreGraphics
@testable import Latent

// MARK: - SAMModelStatus

struct SAMModelStatusTests {

    @Test func notInstalledIsNotReady() {
        #expect(SAMModelStatus.notInstalled.isReady == false)
    }

    @Test func readyIsReady() {
        #expect(SAMModelStatus.ready.isReady == true)
    }

    @Test func errorIsNotReady() {
        #expect(SAMModelStatus.error("load failed").isReady == false)
    }

    @Test func downloadingAtMidpointIsNotReady() {
        #expect(SAMModelStatus.downloading(progress: 0.5).isReady == false)
    }

    @Test func downloadingAtZeroIsNotReady() {
        #expect(SAMModelStatus.downloading(progress: 0.0).isReady == false)
    }

    /// Even at 100 % download progress the model is not yet loaded.
    @Test func downloadingAtOneIsNotReady() {
        #expect(SAMModelStatus.downloading(progress: 1.0).isReady == false)
    }

    // MARK: Equatable

    @Test func sameStatusesAreEqual() {
        #expect(SAMModelStatus.notInstalled == SAMModelStatus.notInstalled)
        #expect(SAMModelStatus.ready        == SAMModelStatus.ready)
    }

    @Test func differentStatusesAreNotEqual() {
        #expect(SAMModelStatus.notInstalled != SAMModelStatus.ready)
        #expect(SAMModelStatus.ready        != SAMModelStatus.error("x"))
    }

    @Test func downloadingWithSameProgressIsEqual() {
        #expect(SAMModelStatus.downloading(progress: 0.3) == SAMModelStatus.downloading(progress: 0.3))
    }

    @Test func downloadingWithDifferentProgressIsNotEqual() {
        #expect(SAMModelStatus.downloading(progress: 0.3) != SAMModelStatus.downloading(progress: 0.7))
    }
}

// MARK: - SAMService (no model installed)

struct SAMServiceTests {

    /// When the Core ML model is absent, generateMask must return nil gracefully
    /// rather than crashing or throwing.
    @Test func generateMaskReturnsNilWhenModelNotInstalled() async {
        let service = SAMService.shared

        // Confirm test environment has no model (skip if model is somehow present).
        let status = await service.status
        guard status == .notInstalled else { return }

        let asset = PhotoAsset(url: URL(filePath: "/tmp/nonexistent.jpg"))
        let mask  = await service.generateMask(
            for:       asset,
            at:        CGPoint(x: 0.5, y: 0.5),
            imageSize: CGSize(width: 1000, height: 1000)
        )
        #expect(mask == nil)
    }

    /// loadModelIfNeeded with no bundle and no cache must leave the service
    /// in a non-ready, non-error state (i.e. .notInstalled).
    @Test func loadModelIfNeededSetsNotInstalledWhenNoBundleExists() async {
        let service = SAMService.shared
        await service.loadModelIfNeeded()
        let status = await service.status
        // In CI / unit-test runs the model is absent → notInstalled.
        // If the model is somehow present → ready is also acceptable.
        #expect(status == .notInstalled || status == .ready)
    }

    /// generateMask with an image that has zero dimensions should not crash.
    @Test func generateMaskWithZeroImageSizeReturnsNil() async {
        let service = SAMService.shared
        let status  = await service.status
        guard status == .notInstalled else { return }

        let asset = PhotoAsset(url: URL(filePath: "/tmp/zero.jpg"))
        let mask  = await service.generateMask(
            for:       asset,
            at:        CGPoint(x: 0.5, y: 0.5),
            imageSize: CGSize(width: 0, height: 0)
        )
        #expect(mask == nil)
    }

    /// generateMask at normalised point (0,0) — top-left corner — should not crash.
    @Test func generateMaskAtOriginReturnsNilWithNoModel() async {
        let service = SAMService.shared
        let status  = await service.status
        guard status == .notInstalled else { return }

        let asset = PhotoAsset(url: URL(filePath: "/tmp/origin.jpg"))
        let mask  = await service.generateMask(
            for:       asset,
            at:        CGPoint(x: 0, y: 0),
            imageSize: CGSize(width: 4000, height: 6000)
        )
        #expect(mask == nil)
    }

    /// generateMask at normalised point (1,1) — bottom-right corner — should not crash.
    @Test func generateMaskAtBottomRightReturnsNilWithNoModel() async {
        let service = SAMService.shared
        let status  = await service.status
        guard status == .notInstalled else { return }

        let asset = PhotoAsset(url: URL(filePath: "/tmp/br.jpg"))
        let mask  = await service.generateMask(
            for:       asset,
            at:        CGPoint(x: 1, y: 1),
            imageSize: CGSize(width: 4000, height: 6000)
        )
        #expect(mask == nil)
    }
}
