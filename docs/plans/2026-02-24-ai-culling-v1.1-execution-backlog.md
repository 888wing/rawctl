# AI Culling v1.1 Execution Backlog (macOS)
**Date**: 2026-02-24  
**Scope**: rawctl macOS app (current Swift/Vision architecture)  
**Status**: Ready for Sprint Planning

---

## 1) Goal

Convert `aicullingspec.docx` into a deliverable next-step plan that matches the current codebase reality.

v1.1 target:
- Keep AI culling fully on-device.
- Upgrade Stage 1 quality and observability.
- Add data contracts that allow future Stage 2/3 integration without rework.

---

## 2) Baseline (Current Implementation)

Current shipped culling path:
- `CullingService` computes `sharpness + saliency + duplicate` and maps to `rating/flag`.
- `AppState.startAICulling()` runs culling and writes back to per-photo recipe metadata.
- Persistence is sidecar JSON (`SidecarService`), not SQLite.
- Progress is shown in `GridView` as a two-phase progress bar.

Impacted modules now:
- `rawctl/Services/CullingService.swift`
- `rawctl/Models/AppState.swift`
- `rawctl/Services/SidecarService.swift`
- `rawctl/Views/GridView.swift`
- `rawctlTests/CullingServiceTests.swift`

---

## 3) v1.1 Scope

### In Scope
- Stage 1 hardening under existing Swift/Vision stack.
- Duplicate output upgrade: from boolean to group-aware structure.
- Exposure-quality scoring and decision contribution.
- Sidecar-compatible culling metadata schema extension.
- Performance and correctness gates for macOS.

### Out of Scope
- Rust pipeline and FFI integration.
- NIMA/Create ML training and inference (Stage 2 in original spec).
- Claude storytelling selection (Stage 3 in original spec).
- SQLite/Core Data migration.

---

## 4) Architecture Delta (v1.1)

### 4.1 Culling Result Contract (new)
Add structured output instead of only `rating/flag`:

```swift
struct CullingAnalysis: Codable, Sendable {
    let version: Int
    let overallScore: Double          // 0...1
    let sharpnessScore: Double        // 0...1
    let saliencyScore: Double         // 0...1
    let exposureScore: Double         // 0...1
    let duplicateGroupId: UUID?       // nil if unique
    let duplicateRank: Int?           // 1 = best in group
    let suggestedRating: Int
    let suggestedFlag: Flag
    let rejectedReasons: [String]     // e.g. ["underexposed", "duplicate_non_best"]
}
```

### 4.2 Duplicate Strategy (v1.1)
- Keep Vision feature print.
- Build duplicate groups using threshold graph/union-find.
- Select one representative per group by score.
- Only non-representative duplicates are auto-reject candidates.

### 4.3 Exposure Quality (v1.1)
- Add histogram-based exposure score.
- Penalize clipped highlights/shadows beyond configurable thresholds.
- Keep artistic tolerance band to avoid over-penalizing low-key style images.

### 4.4 Persistence Strategy
- Keep sidecar JSON as source of truth.
- Save v1.1 culling analysis in sidecar under a versioned section.
- No SQLite in v1.1.

---

## 5) Program Backlog (Epic / Story / Task)

## Epic E1: Stage 1 Scoring Hardening (P0)
**Estimate**: 5-7 days

### Story E1-S1: Exposure scoring
- Task: Implement histogram analyzer in `CullingService`.
- Task: Add `exposureScore` into final weighting.
- Task: Add thresholds in config constants (single source of truth).
- Acceptance:
  - Overexposed/underexposed synthetic fixtures show expected score ordering.
  - No crash on RAW/JPEG/HEIC missing metadata cases.

### Story E1-S2: Weighted score calibration
- Task: Move hardcoded score mapping into explicit table/constants.
- Task: Add calibration fixtures for boundary conditions.
- Acceptance:
  - Rating boundaries deterministic and regression-tested.

## Epic E2: Duplicate Grouping Upgrade (P0)
**Estimate**: 4-6 days

### Story E2-S1: Group-aware dedupe
- Task: Replace `isDuplicate: Bool` with group ID + representative rank.
- Task: Implement representative selection (highest overall score in group).
- Task: Keep fallback path for single-photo/no-feature-print cases.
- Acceptance:
  - Burst-like test fixtures produce stable grouping and one representative.
  - Non-representative items are flagged reject with explicit reason.

### Story E2-S2: Complexity control
- Task: Avoid full O(n²) where possible (pre-filter windows or cached index reuse).
- Task: Reuse `FeaturePrintIndex` where safe.
- Acceptance:
  - 1,000-photo benchmark remains within agreed time budget on Apple Silicon QA machine.

## Epic E3: Data Contract + Persistence (P0)
**Estimate**: 3-4 days

### Story E3-S1: Sidecar schema extension
- Task: Add optional `cullingAnalysis` payload with version.
- Task: Maintain backward compatibility with existing sidecars.
- Task: Roundtrip tests (save -> load -> save) are idempotent.
- Acceptance:
  - Legacy sidecars open without migration failure.
  - v1.1 fields persist and reload accurately.

### Story E3-S2: AppState integration
- Task: `applyCullingResults` writes both legacy `rating/flag` and `cullingAnalysis`.
- Task: Keep existing UX behavior unchanged for non-v1.1-aware views.
- Acceptance:
  - Existing rating/flag workflows continue to work.

## Epic E4: UX and Explainability (P1)
**Estimate**: 2-3 days

### Story E4-S1: Review hints in Grid/Survey
- Task: Add lightweight reason labels for auto-reject/pick suggestion.
- Task: Show duplicate-group context in review UI.
- Acceptance:
  - User can tell why an image was down-ranked without opening logs.

## Epic E5: Test + Perf Gates (P0)
**Estimate**: 3-4 days

### Story E5-S1: Unit/integration tests
- Task: Expand `CullingServiceTests` with exposure, grouping, and threshold regression.
- Task: Add AppState integration tests for sidecar write-through.
- Acceptance:
  - New tests pass in CI.

### Story E5-S2: Performance instrumentation
- Task: Add signposts/metrics for phase timings.
- Task: Capture baseline report (100/500/1000 photos).
- Acceptance:
  - Performance report is attached to release checklist.

## Epic E6: Stage 2/3 Interface Prep (P1)
**Estimate**: 2-3 days

### Story E6-S1: Forward-compatible interfaces only
- Task: Define protocol boundaries for `AestheticScorer` and `NarrativeSelector`.
- Task: Add stub implementations behind feature flags.
- Acceptance:
  - No production behavior change.
  - Future NIMA/Claude integration can plug in without sidecar/schema break.

---

## 6) Milestones

### M1 (Week 1)
- E1 complete.
- Exit criteria:
  - Exposure + score calibration merged.

### M2 (Week 2)
- E2 + E3 complete.
- Exit criteria:
  - Group-aware duplicate output persisted in sidecar.

### M3 (Week 3)
- E4 + E5 complete.
- Exit criteria:
  - Explainability UI shipped.
  - Test/perf gate green.

### M4 (Week 4, optional hardening)
- E6 complete.
- Exit criteria:
  - Stage 2/3 extension interfaces frozen.

---

## 7) Sprint Ticket Template

Each ticket must include:
- Scope boundary (`v1.1 only`, `no Rust`, `no Claude`).
- Impacted files.
- Acceptance tests (unit/integration/manual).
- Performance impact note.
- Rollback note.

---

## 8) Go/No-Go Decision for "Next Development Step"

Decision: **Go, with scope reduction**.

Rationale:
- The original report is valid as long-term direction.
- Immediate next step must be the v1.1 subset above, not full Stage 1/2/3 rollout.
- This avoids architecture mismatch and keeps delivery aligned with existing macOS code.
