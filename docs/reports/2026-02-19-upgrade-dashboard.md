# Latent Upgrade Dashboard
Date: 2026-02-19
Scope: E5-S2 observability consolidation

## Runtime Metrics (E2E panel)
- `scanPhaseMs`: folder scan phase duration.
- `sidecarLoadState`, `sidecarLoadedCount`, `sidecarLoadMs`, `sidecarLoadUs`.
- `sidecarWriteQueued`, `sidecarWriteSkippedNoOp`, `sidecarWriteFlushed`, `sidecarWriteWritten`.
- `thumbnailPreloadState`, `thumbnailPreloadMs`.
- `localExportMatch`, `localPreviewDiff`, `localPreviewHash`, `localExportHash`.

## Signpost Streams
- `folderScanPhase`
- `sidecarLoadAll`
- `renderPreview`
- `thumbnailGenerate`

## Cache Telemetry
Source: `CacheManager.currentStats()`
- thumbnail memory hits / disk hits / misses
- preview hits / misses
- evicted entries / bytes
- churn ratio

## Recommended QA Capture
1. Record one run with `RAWCTL_E2E_STATUS=1`.
2. Save metrics snapshot before and after stress scenario.
3. Attach runbook incident link if any metric crosses alert threshold.

## Alert Heuristics (internal)
- `localExportMatch != "1"` after parity check action.
- `sidecarWriteQueued` rising while `sidecarWriteWritten` flat for >30s.
- cache churn ratio sustained >0.6 during simple browse workloads.
