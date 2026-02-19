# Latent Upgrade Acceptance Pack
Date: 2026-02-19
Scope: E5-S3 go/no-go package

## A) Automated Suites
Run once from repo root:

```bash
./scripts/run-upgrade-acceptance.sh
```

This bundles:
- Smoke gates (critical user paths on `rawctl-e2e` scheme).
- Golden correctness / parity gates.
- Sidecar migration + state hygiene gates.
- Cache eviction + Smart Collection capture-date regressions.

Smoke suite currently executes:
- `RawctlSmokeTests/testSmoke_LaunchWithFolderAndSwitchViews`
- `RawctlSmokeTests/testEntry_InspectorEditCropSwitchesSingleAndTransform`
- `RawctlSmokeTests/testSmoke_ExternalFolderSidecarLoadCompletes`
- `RawctlSmokeTests/testSmoke_ExternalFolderLocalExportConsistency`

## B) Required Manual Smoke Checklist
Mark each item pass/fail with evidence (screenshot/log link).

1. Open folder with mixed RAW/JPEG/HEIC and verify first selection latency is acceptable.
2. Apply global adjustments, local masks, AI edits, and AI layers on one photo.
3. Switch between grid/single repeatedly; ensure edits persist after app relaunch.
4. Export current photo; visually compare preview and export for parity.
5. Import from memory card entry point (when feature flag enabled) and confirm open/import path is not dead-end.
6. Validate Smart Collection capture-date rule using at least one boundary-day sample.
7. Trigger `Check for Updates…` on a signed build and verify appcast/signature path is healthy.

## C) Go/No-Go Criteria
- Go only if:
  - automated acceptance script exits 0
  - all manual smoke items pass
  - capability checklist release-blocking items are all checked
  - runbook owner confirms rollback path is ready
- No-Go if any P0 correctness or migration issue is unresolved.

## D) Decision Record Template
Use this template in release thread:

```text
Release: v<version>
Decision: GO | NO-GO
Owner: <name>
Automated suites: PASS | FAIL
Manual smoke: PASS | FAIL
Known risks:
- <risk 1>
- <risk 2>
Rollback readiness: READY | NOT READY
Notes:
- <links to evidence>
```
