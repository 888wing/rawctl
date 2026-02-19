#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "== Upgrade Acceptance Pack =="
echo "Project: ${PROJECT_ROOT}"
echo ""

echo "1) Smoke gates (critical user paths)"
xcodebuild -project rawctl.xcodeproj -scheme rawctl-e2e -destination 'platform=macOS' test \
  -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_LaunchWithFolderAndSwitchViews \
  -only-testing:rawctlUITests/RawctlSmokeTests/testEntry_InspectorEditCropSwitchesSingleAndTransform \
  -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_ExternalFolderSidecarLoadCompletes \
  -only-testing:rawctlUITests/RawctlSmokeTests/testSmoke_ExternalFolderLocalExportConsistency

echo ""
echo "2) Golden correctness gates (preview/export parity + layer ordering)"
xcodebuild -project rawctl.xcodeproj -scheme rawctl -destination 'platform=macOS' test \
  -only-testing:rawctlTests/RenderContextBuilderTests \
  -only-testing:rawctlTests/LayerCompositingOrderTests \
  -only-testing:rawctlTests/ImagePipelineRegressionTests/renderContextPreviewAndExportAreAligned \
  -only-testing:rawctlTests/ImagePipelineRegressionTests/aiLayerCompositingAffectsRenderWhenVisible \
  -only-testing:rawctlTests/ImagePipelineRegressionTests/aiEditCompositingAffectsRenderWhenEnabled

echo ""
echo "3) Sidecar migration + state hygiene gates"
xcodebuild -project rawctl.xcodeproj -scheme rawctl -destination 'platform=macOS' test \
  -only-testing:rawctlTests/SidecarMigrationTests \
  -only-testing:rawctlTests/FileSystemServiceCacheMigrationTests \
  -only-testing:rawctlTests/SidecarServiceTests \
  -only-testing:rawctlTests/AppStateRefreshCleanupTests \
  -only-testing:rawctlTests/AppStateSidecarFlushTests

echo ""
echo "4) Upgrade regression gates (cache eviction + smart collection capture date)"
xcodebuild -project rawctl.xcodeproj -scheme rawctl -destination 'platform=macOS' test \
  -only-testing:rawctlTests/CacheEvictionTests \
  -only-testing:rawctlTests/SmartCollectionTests \
  -only-testing:rawctlTests/AppStateCatalogTests \
  -only-testing:rawctlTests/StateCoordinatorTests \
  -only-testing:rawctlTests/AppStatePreloadTuningTests

echo ""
echo "All automated acceptance suites completed."
echo "Continue with manual checklist: docs/reports/2026-02-19-upgrade-acceptance-pack.md"
