//
//  RawctlSmokeTests.swift
//  rawctlUITests
//

import XCTest
import AppKit

final class RawctlSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func waitForValue(_ element: XCUIElement, matches regex: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value MATCHES %@", regex)
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, equals expected: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    private func waitForValue(_ element: XCUIElement, notEquals unexpected: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "value != %@", unexpected)
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [exp], timeout: timeout) == .completed
    }

    private func waitForNumericValue(_ element: XCUIElement, timeout: TimeInterval) -> Int? {
        func parseNumber(_ raw: Any?) -> Int? {
            if let num = raw as? NSNumber {
                return num.intValue
            }

            let text: String
            if let str = raw as? String {
                text = str
            } else if let raw {
                text = String(describing: raw)
            } else {
                return nil
            }

            // Accept plain numbers and wrapped/annotated forms, e.g. "Optional(123)" or "123 ms".
            let normalized = text.replacingOccurrences(of: "Optional(", with: "").replacingOccurrences(of: ")", with: "")
            let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedGrouping = trimmed
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let strict = Int(normalizedGrouping) {
                return strict
            }

            let pattern = try? NSRegularExpression(pattern: "-?[0-9][0-9,._ ]*")
            let nsText = trimmed as NSString
            guard let match = pattern?.firstMatch(in: trimmed, range: NSRange(location: 0, length: nsText.length)) else {
                return nil
            }
            let token = nsText.substring(with: match.range)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            return Int(token)
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let value = parseNumber(element.value) {
                return value
            }
            usleep(100_000) // 100ms
        }

        return nil
    }

    /// Ensure the app-under-test is fully stopped between relaunch samples.
    /// Prevents occasional "Running Background" activation failures on macOS UI tests.
    private func terminateResidualRawctlApp() {
        let bundleId = "Shacoworkshop.rawctl"
        let deadline = Date().addingTimeInterval(5.0)
        while Date() < deadline {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            guard !runningApps.isEmpty else { return }

            for running in runningApps {
                if running.isTerminated {
                    continue
                }
                _ = running.terminate()
                usleep(120_000)
                if !running.isTerminated {
                    _ = running.forceTerminate()
                }
            }

            usleep(200_000)
        }
    }

    /// Build a deterministic fixture folder with image files and optional sidecars.
    /// Used for cold/hot split performance measurements.
    private func createSidecarFixtureFolder(
        count: Int,
        includeSidecars: Bool = true,
        sidecarPayloadBytes: Int = 0,
        benchmarkVectorCount: Int = 0
    ) throws -> String {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("rawctl-e2e-sidecar-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+Gx0AAAAASUVORK5CYII="
        guard let pngData = Data(base64Encoded: pngBase64) else {
            throw NSError(domain: "RawctlSmokeTests", code: 1)
        }

        let payloadByteCount = max(0, sidecarPayloadBytes)
        let payload: String = {
            guard payloadByteCount > 0 else { return "" }
            let unit = "rawctl_e2e_payload_"
            let unitBytes = unit.utf8.count
            let repeats = (payloadByteCount + unitBytes - 1) / unitBytes
            let expanded = String(repeating: unit, count: repeats)
            return String(expanded.prefix(payloadByteCount))
        }()
        let vectorCount = max(0, benchmarkVectorCount)
        let benchmarkVectors: [[String: Any]] = {
            guard vectorCount > 0 else { return [] }
            return (0..<vectorCount).map { index in
                [
                    "id": index,
                    "luma": Double((index * 17) % 100) / 100.0,
                    "hue": Double((index * 31) % 360),
                    "saturation": Double((index * 11) % 100) / 100.0,
                    "temperature": 5200 + ((index * 83) % 1800),
                    "noiseProfile": [
                        "luma": Double((index * 7) % 40) / 100.0,
                        "chroma": Double((index * 9) % 40) / 100.0,
                    ],
                ]
            }
        }()

        let fileCount = max(1, count)
        for i in 1...fileCount {
            let filename = String(format: "E2E_%03d.png", i)
            let imageURL = dir.appendingPathComponent(filename)
            try pngData.write(to: imageURL, options: .atomic)

            guard includeSidecars else { continue }

            let attrs = try fm.attributesOfItem(atPath: imageURL.path)
            let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

            var sidecar: [String: Any] = [
                "schemaVersion": 5,
                "asset": [
                    "originalFilename": filename,
                    "fileSize": Int64(pngData.count),
                    "modifiedTime": modified,
                ],
                "edit": [:],
                "snapshots": [],
                "aiEdits": [],
                "updatedAt": Date().timeIntervalSince1970,
            ]
            if !payload.isEmpty {
                sidecar["benchmarkPayload"] = payload
            }
            if !benchmarkVectors.isEmpty {
                sidecar["benchmarkVectors"] = benchmarkVectors
            }

            let sidecarURL = dir.appendingPathComponent("\(filename).rawctl.json")
            let data = try JSONSerialization.data(withJSONObject: sidecar, options: [])
            try data.write(to: sidecarURL, options: .atomic)
        }

        return dir.path
    }

    @MainActor
    func testSmoke_LaunchWithExternalFolderAndSwitchViews() throws {
        guard let folderUnderTest = ProcessInfo.processInfo.environment["RAWCTL_E2E_FOLDER_UNDER_TEST"],
              !folderUnderTest.isEmpty else {
            throw XCTSkip("Set RAWCTL_E2E_FOLDER_UNDER_TEST to run external-folder smoke test")
        }

        let app = XCUIApplication()
        defer { app.terminate() }

        app.launchEnvironment["RAWCTL_E2E_FOLDER"] = folderUnderTest
        app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
        app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
        app.launch()

        let assetsCount = app.descendants(matching: .any)["e2e.assets.count"]
        XCTAssertTrue(waitForValue(assetsCount, matches: "[1-9][0-9]*", timeout: 30))

        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.exists"], equals: "1", timeout: 10))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.filename"], matches: ".+", timeout: 10))

        let viewMenu = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 5))
        viewMenu.click()

        let gridMenuItem = viewMenu.menus.menuItems["Grid View (E2E)"]
        let singleMenuItem = viewMenu.menus.menuItems["Single View (E2E)"]
        XCTAssertTrue(gridMenuItem.waitForExistence(timeout: 2))
        XCTAssertTrue(singleMenuItem.waitForExistence(timeout: 2))

        singleMenuItem.click()
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "single", timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["singleView"].waitForExistence(timeout: 8))

        viewMenu.click()
        gridMenuItem.click()
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "grid", timeout: 8))
    }

    @MainActor
    func testSmoke_ExternalFolderInspectorEditCropEntry() throws {
        guard let folderUnderTest = ProcessInfo.processInfo.environment["RAWCTL_E2E_FOLDER_UNDER_TEST"],
              !folderUnderTest.isEmpty else {
            throw XCTSkip("Set RAWCTL_E2E_FOLDER_UNDER_TEST to run external-folder crop entry smoke test")
        }

        let app = XCUIApplication()
        defer { app.terminate() }

        app.launchEnvironment["RAWCTL_E2E_FOLDER"] = folderUnderTest
        app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
        app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
        app.launch()

        let assetsCount = app.descendants(matching: .any)["e2e.assets.count"]
        XCTAssertTrue(waitForValue(assetsCount, matches: "[1-9][0-9]*", timeout: 30))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.exists"], equals: "1", timeout: 12))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.filename"], matches: ".+", timeout: 12))

        let editCrop = app.descendants(matching: .any)["inspector.edit.crop"]
        XCTAssertTrue(editCrop.waitForExistence(timeout: 15))
        editCrop.click()

        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "single", timeout: 12))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.transform.mode"], equals: "1", timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["singleView"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testSmoke_ExternalFolderSliderStressInteraction() throws {
        guard let folderUnderTest = ProcessInfo.processInfo.environment["RAWCTL_E2E_FOLDER_UNDER_TEST"],
              !folderUnderTest.isEmpty else {
            throw XCTSkip("Set RAWCTL_E2E_FOLDER_UNDER_TEST to run external-folder slider stress smoke test")
        }

        let app = XCUIApplication()
        defer { app.terminate() }

        app.launchEnvironment["RAWCTL_E2E_FOLDER"] = folderUnderTest
        app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
        app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
        app.launch()

        let assetsCount = app.descendants(matching: .any)["e2e.assets.count"]
        XCTAssertTrue(waitForValue(assetsCount, matches: "[1-9][0-9]*", timeout: 30))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.exists"], equals: "1", timeout: 12))

        let state = app.descendants(matching: .any)["e2e.slider.stress.state"]
        _ = waitForValue(state, notEquals: "running", timeout: 8)

        let stressButton = app.descendants(matching: .any)["e2e.action.slider.stress"]
        XCTAssertTrue(stressButton.waitForExistence(timeout: 10))
        stressButton.click()
        XCTAssertTrue(waitForValue(state, equals: "done", timeout: 45))
    }

    @MainActor
    func testSmoke_LaunchWithFolderAndSwitchViews() throws {
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
        app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "6"
        app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
        app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
        app.launch()

        // Ensure folder scan completed and UI state is ready.
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "6", timeout: 15))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.exists"], equals: "1", timeout: 5))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.filename"], equals: "E2E_001.png", timeout: 5))

        // Wait until the grid is populated with a known element.
        let first = app.descendants(matching: .any)["grid.thumbnail.E2E_001.png"]
        XCTAssertTrue(first.waitForExistence(timeout: 15))

        // Verify menu entry points exist.
        let viewMenu = app.menuBars.menuBarItems["View"]
        XCTAssertTrue(viewMenu.waitForExistence(timeout: 5))
        viewMenu.click()
        let gridMenuItem = viewMenu.menus.menuItems["Grid View (E2E)"]
        let singleMenuItem = viewMenu.menus.menuItems["Single View (E2E)"]
        XCTAssertTrue(gridMenuItem.waitForExistence(timeout: 2))
        XCTAssertTrue(singleMenuItem.waitForExistence(timeout: 2))

        // Switch views via the View menu entry points (primary user-facing UI).
        // If these don't fire, UI automation is not reliably delivering click events.
        singleMenuItem.click()
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "single", timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["singleView"].waitForExistence(timeout: 5))

        viewMenu.click()
        gridMenuItem.click()
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "grid", timeout: 5))
        XCTAssertTrue(first.waitForExistence(timeout: 5))
    }

    @MainActor
    func testEntry_InspectorEditCropSwitchesSingleAndTransform() throws {
        let app = XCUIApplication()
        defer { app.terminate() }
        app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
        app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "6"
        app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
        app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
        app.launch()

        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "6", timeout: 15))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.selected.exists"], equals: "1", timeout: 8))

        let editCrop = app.descendants(matching: .any)["inspector.edit.crop"]
        XCTAssertTrue(editCrop.waitForExistence(timeout: 10))
        editCrop.click()

        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.view.mode"], equals: "single", timeout: 8))
        XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.transform.mode"], equals: "1", timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["singleView"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testPerf_folderToFirstSelectionSignpost() throws {
        // Validate harness before measure.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.first.selection.ms"], matches: "[1-9][0-9]*", timeout: 20))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "folderToFirstSelection"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let latency = app.descendants(matching: .any)["e2e.first.selection.ms"]
            _ = waitForValue(latency, matches: "[1-9][0-9]*", timeout: 20)
            app.terminate()
        }
    }

    @MainActor
    func testPerf_sliderStressSignpost() throws {
        // Validate harness before measure.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "20"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "20", timeout: 20))

            let stressButton = app.descendants(matching: .any)["e2e.action.slider.stress"]
            XCTAssertTrue(stressButton.waitForExistence(timeout: 8))
            stressButton.click()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.slider.stress.state"], equals: "done", timeout: 20))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "sliderStress"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "20"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let count = app.descendants(matching: .any)["e2e.assets.count"]
            _ = waitForValue(count, equals: "20", timeout: 20)

            let state = app.descendants(matching: .any)["e2e.slider.stress.state"]
            _ = waitForValue(state, notEquals: "running", timeout: 5)
            let stressButton = app.descendants(matching: .any)["e2e.action.slider.stress"]
            stressButton.click()
            _ = waitForValue(state, equals: "done", timeout: 20)
            app.terminate()
        }
    }

    @MainActor
    func testPerf_scanFolderSignpost() throws {
        // Validate the sandbox-safe harness once outside of `measure`, otherwise failures turn into very slow timeouts.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "50"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "50", timeout: 15))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "scanFolder"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "50"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let count = app.descendants(matching: .any)["e2e.assets.count"]
            // Don't terminate before scan finishes, otherwise the signpost interval may not complete.
            _ = waitForValue(count, equals: "50", timeout: 15)
            app.terminate()
        }
    }

    @MainActor
    func testPerf_folderScanPhaseSignpost() throws {
        // Validate harness before measure.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "120", timeout: 20))
            XCTAssertNotNil(waitForNumericValue(app.descendants(matching: .any)["e2e.scan.phase.ms"], timeout: 8))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "folderScanPhase"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let count = app.descendants(matching: .any)["e2e.assets.count"]
            _ = waitForValue(count, equals: "120", timeout: 20)
            _ = waitForNumericValue(app.descendants(matching: .any)["e2e.scan.phase.ms"], timeout: 8)
            app.terminate()
        }
    }

    @MainActor
    func testPerf_sidecarLoadSignpost() throws {
        // Validate harness before measure.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "120", timeout: 20))
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.sidecar.load.state"], equals: "done", timeout: 40))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "sidecarLoadAll"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let count = app.descendants(matching: .any)["e2e.assets.count"]
            _ = waitForValue(count, equals: "120", timeout: 20)
            let sidecar = app.descendants(matching: .any)["e2e.sidecar.load.state"]
            _ = waitForValue(sidecar, equals: "done", timeout: 40)
            app.terminate()
        }
    }

    @MainActor
    func testPerf_sidecarLoadColdHotSplit() throws {
        let fixtureCount = 240
        let payloadBytesPerFile = 262_144
        let vectorCountPerFile = 24
        let folderPath = try createSidecarFixtureFolder(
            count: fixtureCount,
            includeSidecars: true,
            sidecarPayloadBytes: payloadBytesPerFile,
            benchmarkVectorCount: vectorCountPerFile
        )

        func launchAndReadSidecarUs() -> Int? {
            terminateResidualRawctlApp()
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_FOLDER"] = folderPath
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            defer { app.terminate() }

            guard waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "\(fixtureCount)", timeout: 30) else {
                return nil
            }
            guard waitForValue(app.descendants(matching: .any)["e2e.sidecar.load.state"], equals: "done", timeout: 40) else {
                return nil
            }
            guard waitForValue(app.descendants(matching: .any)["e2e.sidecar.loaded.count"], equals: "\(fixtureCount)", timeout: 10) else {
                return nil
            }
            if let us = waitForNumericValue(app.descendants(matching: .any)["e2e.sidecar.load.us"], timeout: 20) {
                return us
            }
            if let ms = waitForNumericValue(app.descendants(matching: .any)["e2e.sidecar.load.ms"], timeout: 20) {
                return ms * 1_000
            }
            return nil
        }

        func percentile(_ values: [Int], p: Double) -> Int {
            guard !values.isEmpty else { return 0 }
            let sorted = values.sorted()
            let clamped = max(0.0, min(1.0, p))
            let rawIndex = Int((Double(sorted.count - 1) * clamped).rounded())
            return sorted[rawIndex]
        }

        func launchAndReadSidecarUsWithRetry(maxAttempts: Int) -> Int? {
            var attempts = max(1, maxAttempts)
            while attempts > 0 {
                if let value = launchAndReadSidecarUs() {
                    return value
                }
                attempts -= 1
                if attempts > 0 {
                    usleep(300_000) // 300ms backoff between launches.
                }
            }
            return nil
        }

        guard let coldUs = launchAndReadSidecarUsWithRetry(maxAttempts: 3) else {
            XCTFail("Unable to capture cold sidecar load")
            return
        }

        let warmSampleCount = 1
        var warmSamplesUs: [Int] = []
        for _ in 0..<warmSampleCount {
            guard let warm = launchAndReadSidecarUsWithRetry(maxAttempts: 3) else {
                XCTFail("Unable to capture warm sidecar load sample")
                return
            }
            warmSamplesUs.append(warm)
        }

        let warmMedianUs = percentile(warmSamplesUs, p: 0.50)
        let warmP95Us = percentile(warmSamplesUs, p: 0.95)
        let coldMs = String(format: "%.3f", Double(coldUs) / 1_000.0)
        let warmMedianMs = String(format: "%.3f", Double(warmMedianUs) / 1_000.0)
        let warmP95Ms = String(format: "%.3f", Double(warmP95Us) / 1_000.0)
        let estimatedSidecarMiB = (Double(fixtureCount * payloadBytesPerFile) / 1024.0 / 1024.0)
        let estimatedPayloadMiBText = String(format: "%.1f", estimatedSidecarMiB)
        let summary =
            "fixtureCount=\(fixtureCount), payloadBytesPerFile=\(payloadBytesPerFile), vectorCountPerFile=\(vectorCountPerFile), estimatedPayloadMiB=\(estimatedPayloadMiBText), coldUs=\(coldUs) (\(coldMs)ms), warmSamplesUs=\(warmSamplesUs), warmMedianUs=\(warmMedianUs) (\(warmMedianMs)ms), warmP95Us=\(warmP95Us) (\(warmP95Ms)ms)"
        print("[Perf][sidecarColdHot] \(summary)")
        add(XCTAttachment(string: summary))

        XCTAssertGreaterThan(coldUs, 0)
        XCTAssertGreaterThan(warmMedianUs, 0)
    }

    @MainActor
    func testPerf_thumbnailPreloadSignpost() throws {
        // Validate harness before measure.
        do {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.assets.count"], equals: "120", timeout: 20))
            XCTAssertTrue(waitForValue(app.descendants(matching: .any)["e2e.thumbnail.preload.state"], equals: "done", timeout: 60))
            app.terminate()
        }

        let metric = XCTOSSignpostMetric(
            subsystem: "Shacoworkshop.rawctl",
            category: "performance",
            name: "thumbnailPreloadAll"
        )

        measure(metrics: [metric]) {
            let app = XCUIApplication()
            app.launchEnvironment["RAWCTL_E2E_GENERATE_FIXTURES"] = "1"
            app.launchEnvironment["RAWCTL_E2E_FIXTURE_COUNT"] = "120"
            app.launchEnvironment["RAWCTL_DISABLE_WHATS_NEW"] = "1"
            app.launchEnvironment["RAWCTL_SIGNPOSTS"] = "1"
            app.launchEnvironment["RAWCTL_E2E_STATUS"] = "1"
        app.launchEnvironment["RAWCTL_E2E_PANEL"] = "1"
            app.launch()

            let count = app.descendants(matching: .any)["e2e.assets.count"]
            _ = waitForValue(count, equals: "120", timeout: 20)
            let thumbs = app.descendants(matching: .any)["e2e.thumbnail.preload.state"]
            _ = waitForValue(thumbs, equals: "done", timeout: 60)
            app.terminate()
        }
    }
}
