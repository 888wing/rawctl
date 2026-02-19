# Latent Release + Incident Runbook
Date: 2026-02-19
Scope: E5-S2 operational hardening

## 1) Observability Sources
- App signposts:
  - `folderScanPhase`
  - `sidecarLoadAll`
  - `renderPreview`
  - `thumbnailGenerate`
- E2E status panel keys (RAWCTL_E2E_STATUS=1):
  - `sidecarWriteQueued`
  - `sidecarWriteSkippedNoOp`
  - `sidecarWriteFlushed`
  - `sidecarWriteWritten`
  - `sidecarLoadState`
  - `localExportMatch`
  - `localPreviewDiff`
- Cache telemetry snapshots:
  - `CacheManager.currentStats()` for hit/miss/eviction/churn.

## 2) Release Rollback Procedure
Use when a production artifact is bad but prior version is known-good.

1. Identify target rollback version `X.Y.Z` and verify corresponding DMG/appcast entry exists.
2. Re-point release endpoints:
   - Upload known-good DMG as `latent-latest.dmg`.
   - Restore known-good `appcast.xml` entry to top item.
3. Validate remote artifacts:
   - Verify `appcast.xml` contains matching `sparkle:shortVersionString` and `sparkle:edSignature`.
   - Verify DMG checksum matches expected `.sha256`.
4. Verify client behavior:
   - Launch app, run `Check for Updates…`, ensure rollback candidate is detected.
5. Announce rollback completion and open follow-up incident for root cause.

## 3) Sidecar Migration Failure Procedure
Use when users report missing edits after `.rawctl.json` -> `.latent.json` migration.

1. Confirm affected asset path and inspect sidecar files:
   - check `<asset>.latent.json`
   - check legacy `<asset>.rawctl.json`
2. If legacy file exists and new file missing:
   - backup both files.
   - run app once on the folder to trigger migration path in `SidecarService`.
3. If both files exist but content diverges:
   - treat `.latent.json` as active.
   - manually merge missing fields from legacy file (`edit`, `snapshots`, `localNodes`, `aiEdits`, `aiLayers`) into active file backup copy.
4. Validate by reopening folder and confirming preview/export parity for impacted assets.
5. Add failing sample to migration fixtures and extend `SidecarMigrationTests` before next release.

## 4) Pre-Release Health Checks
1. Run `scripts/run-upgrade-acceptance.sh`.
2. Run `scripts/verify-capability-checklist.sh` and `scripts/verify-release-note-evidence.sh`.
3. Confirm `.github/workflows/release.yml` checks pass in CI.
4. Confirm capability checklist has all release-blocking items checked:
   - `docs/plans/2026-02-19-capability-checklist.md`

## 5) Post-Release Monitoring Window (first 24h)
1. Monitor update failures and Sparkle signature/appcast issues.
2. Monitor sidecar write metrics trend (queued vs flushed vs written).
3. Spot-check 3 real-world folders:
   - open folder
   - apply edit
   - quit/reopen
   - validate edit persistence.
