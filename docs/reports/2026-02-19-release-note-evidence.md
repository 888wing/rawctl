# Latent Release Note Evidence Map
Date: 2026-02-19
Version: 1.4.0

- Claim: Local mask workflow is now fully integrated into day-to-day editing
  Evidence: `rawctl/Models/AppState.swift`, `rawctl/Views/SingleView.swift`, `rawctl/Views/InspectorView.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Linear and brush mask interactions are now stable and predictable
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctl/Views/SingleView.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Local adjustments are consistently applied in preview and export
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/ImagePipelineRegressionTests.swift`, `rawctlTests/LayerCompositingOrderTests.swift`
- Claim: Selection, save, and render flows are smoother under heavy editing
  Evidence: `rawctl/Models/AppState.swift`, `rawctl/Services/SidecarService.swift`, `rawctlUITests/RawctlSmokeTests.swift`
- Claim: Local Adjustment workflow with Radial, Linear, and Brush masks is now production-ready
  Evidence: `rawctl/Views/SingleView.swift`, `rawctl/Views/InspectorView.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Inspector supports direct local-node editing mode with clear context and exit flow
  Evidence: `rawctl/Views/InspectorView.swift`, `rawctl/Models/AppState.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Export pipeline now receives localNodes so output matches on-screen edits
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctl/Services/ExportService.swift`, `rawctlTests/ImagePipelineRegressionTests.swift`
- Claim: E2E local parity checks added for preview/export hash and diff monitoring
  Evidence: `rawctl/Views/MainLayoutView.swift`, `rawctlUITests/RawctlSmokeTests.swift`
- Claim: Linear mask geometry unified between editor and renderer for consistent placement
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctl/Views/SingleView.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Brush mask keeps bitmap continuity so users can reopen and continue painting
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Selection flow now clears stale mask-editing state when switching photos
  Evidence: `rawctl/Models/AppState.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Recipe persistence now uses debounced saves plus flush on context switches for smoother interaction
  Evidence: `rawctl/Models/AppState.swift`, `rawctl/Services/SidecarService.swift`, `rawctlTests/AppStateSidecarFlushTests.swift`
- Claim: Linear mask position/falloff mismatches that caused visual offset and jumpy dragging
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Invalid brush fallback that could incorrectly apply edits across the full image
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/ImagePipelineRegressionTests.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Local opacity/blend controls not taking effect in final local compositing
  Evidence: `rawctl/Services/ImagePipeline.swift`, `rawctlTests/NodeGraphTests.swift`
- Claim: Narrow-window filter/selection bars overflowing and deforming the UI
  Evidence: `rawctl/Views/MainLayoutView.swift`, `rawctl/Views/WorkspaceView.swift`, `rawctl/Views/SingleView.swift`
