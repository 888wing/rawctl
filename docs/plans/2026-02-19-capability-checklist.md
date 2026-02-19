# Latent Capability Checklist (Release Prep)
Date: 2026-02-19
Owner: Core Product + Imaging

## Release Blocking Items
- [x] Preview/export use unified `RenderContext` contract.
  Evidence: `rawctl/Models/RenderContext.swift`, `rawctl/Services/ImagePipeline.swift`, `rawctl/Services/ExportService.swift`
- [x] AI edits and AI layers are both visible in preview and export.
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/ImagePipelineRegressionTests.swift`, `rawctlTests/LayerCompositingOrderTests.swift`
- [x] Sidecar schema migration is backward-compatible and roundtrip-safe.
  Evidence: `rawctl/Models/EditRecipe.swift`, `rawctl/Services/SidecarService.swift`, `rawctlTests/SidecarMigrationTests.swift`, `rawctlTests/SidecarServiceTests.swift`
- [x] Incremental refresh cleanup removes stale recipe/local/AI state atomically.
  Evidence: `rawctl/Models/AppState.swift`, `rawctlTests/AppStateRefreshCleanupTests.swift`
- [x] Sidecar write coalescing tracks queued/skipped/flushed/written and lifecycle flush is present.
  Evidence: `rawctl/Services/SidecarService.swift`, `rawctl/Views/MainLayoutView.swift`, `rawctl/Models/AppState.swift`, `rawctlTests/AppStateSidecarFlushTests.swift`
- [x] AppState orchestration is split via Selection/EditState/LibrarySync coordinators.
  Evidence: `rawctl/Models/StateCoordinators.swift`, `rawctl/Models/AppState.swift`, `rawctlTests/StateCoordinatorTests.swift`
- [x] Memory-pressure eviction path is real (not placeholder) with telemetry.
  Evidence: `rawctl/Services/CacheManager.swift`, `rawctl/Services/ThumbnailService.swift`, `rawctl/Services/ImagePipeline.swift`, `rawctlTests/CacheEvictionTests.swift`
- [x] Sidebar entry points avoid dead-end actions in production.
  Evidence: `rawctl/Models/AppFeatures.swift`, `rawctl/Components/Sidebar/LibrarySection.swift`, `rawctl/Components/Sidebar/DevicesSection.swift`, `rawctl/Views/SidebarView.swift`
- [x] Smart Collection capture-date rule is functional with fallback and boundary coverage.
  Evidence: `rawctl/Models/SmartCollection.swift`, `rawctlTests/SmartCollectionTests.swift`
- [x] Release workflow enforces Sparkle signature generation and appcast validation.
  Evidence: `.github/workflows/release.yml`, `scripts/update-appcast.sh`
- [x] Release-note claims are mapped to code/test evidence and checked in CI.
  Evidence: `docs/reports/2026-02-19-release-note-evidence.md`, `scripts/verify-release-note-evidence.sh`, `.github/workflows/release.yml`

## Non-Blocking but Tracked
- [x] Large-library sidecar/thumbnail loading applies tuned backpressure and preload windows.
  Evidence: `rawctl/Models/AppState.swift`, `rawctlTests/AppStatePreloadTuningTests.swift`
- [x] Upgrade acceptance script aggregates required automated suites.
  Evidence: `scripts/run-upgrade-acceptance.sh`, `rawctlUITests/RawctlSmokeTests.swift`, `rawctlTests/ImagePipelineRegressionTests.swift`
- [x] Incident runbook exists for rollback and migration failures.
  Evidence: `docs/reports/2026-02-19-release-ops-runbook.md`
- [x] Go/no-go acceptance pack exists and is usable by QA.
  Evidence: `docs/reports/2026-02-19-upgrade-acceptance-pack.md`
