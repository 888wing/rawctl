# rawctl vNext Upgrade Master Plan
**Date**: 2026-02-19
**Owner**: Core Product + Imaging
**Planning Horizon**: 10 weeks
**Status**: Draft for execution

---

## 1) Executive Summary

rawctl has a stable core (all tests passing) and a complete end-to-end product path, but upgrade planning should prioritize correctness and integration gaps before feature expansion.

Primary upgrade target:
- Close rendering/data consistency gaps (especially AI edit integration).
- Harden memory/cache and release pipeline.
- Align UI surface with real shipped capabilities.

This document defines a full Epic/Story/Task backlog with effort estimates and milestone gates.

---

## 2) Current Baseline

### System Health
- Build/test baseline is green on macOS (`xcodebuild test` succeeded on 2026-02-19).
- Architecture is clear but has several oversized files (state/pipeline/view monoliths), which raises change risk.

### Main Technical Risks to Address First
1. AI layers/history are persisted in app state/sidecar flows but not fully consumed in render/export pipeline.
2. Incremental refresh cleanup order may leave stale recipe state.
3. Cache memory-pressure eviction paths are partially stubbed.
4. UI/features contain placeholders or non-functional rules (Devices, Recent Imports, capture-date rule).
5. Release notes and implementation coverage can drift (capability signaling risk).

---

## 3) Planning Assumptions

- Team capacity baseline: 2 engineers + 1 QA (shared).
- Estimate unit: **ideal engineering days** (excludes review and wait time).
- Weekly release cadence for internal builds, bi-weekly candidate for external preview.
- No schema-breaking migration without forward/backward compatibility strategy.

---

## 4) Upgrade Goals and KPIs

### G1 Correctness (P0)
- All edit states (global/local/AI) render identically across preview and export.
- KPI:
  - 0 known parity bugs between preview/export on golden set.
  - 100% pass for new render parity tests.

### G2 Reliability (P1)
- Stable behavior under memory pressure and large folders.
- KPI:
  - No crash in 2-hour stress session (5k assets browsing).
  - Cache hit ratio and eviction telemetry available.

### G3 Product Consistency (P1/P2)
- Sidebar/menu/documentation only expose real working features.
- KPI:
  - 0 placeholder entry points in production build.
  - Release notes map to implemented feature checklist.

---

## 5) Program Backlog (Epic / Story / Task)

## Epic E1: Render Correctness and AI Integration (P0)
**Target**: Week 1-3  
**Estimate**: 14-18 days

### Story E1-S1: Unify render input contract
**Estimate**: 3-4 days
- Task: Define `RenderContext` model (recipe + localNodes + aiLayers + aiEdits + color/profile metadata).
- Task: Refactor preview API to consume `RenderContext`.
- Task: Refactor export API to consume the same `RenderContext`.
- Task: Add compile-time guards to prevent old API path usage.

### Story E1-S2: Integrate AI layers into pipeline stages
**Estimate**: 5-6 days
- Task: Map AI layer stack to compositing operations with deterministic ordering.
- Task: Define blend/opacity semantics and defaults for missing values.
- Task: Add fallback path for legacy sidecars without AI section.
- Task: Add unit tests for layer ordering and alpha behavior.

### Story E1-S3: Preview/export parity test framework
**Estimate**: 4-5 days
- Task: Build golden-image fixture pack (RAW + JPEG + HEIC, with AI + local masks).
- Task: Add pixel-diff threshold test harness.
- Task: Add CI job gate for parity suite.

### Story E1-S4: Sidecar migration compatibility validation
**Estimate**: 2-3 days
- Task: Add migration tests for old schema to new in-memory shape.
- Task: Add idempotent save/load roundtrip tests.

---

## Epic E2: Data Consistency and State Hygiene (P0/P1)
**Target**: Week 2-4  
**Estimate**: 9-12 days

### Story E2-S1: Fix incremental refresh cleanup ordering
**Estimate**: 2-3 days
- Task: Correct removal flow to compute stale asset IDs before mutation.
- Task: Ensure recipe/sidecar state is cleaned atomically.
- Task: Add regression tests for delete/move/rename sequences.

### Story E2-S2: Sidecar write coalescing hardening
**Estimate**: 3-4 days
- Task: Audit debounce semantics per-asset under rapid edits.
- Task: Add cancellation safety for view switches and app background transitions.
- Task: Add observability counters (queued, skipped-noop, flushed).

### Story E2-S3: State module decomposition
**Estimate**: 4-5 days
- Task: Split `AppState` into focused coordinators:
  - `SelectionCoordinator`
  - `EditStateCoordinator`
  - `LibrarySyncCoordinator`
- Task: Preserve current behavior via facade API to minimize UI churn.

---

## Epic E3: Performance and Memory (P1)
**Target**: Week 4-7  
**Estimate**: 12-16 days

### Story E3-S1: Implement real memory-pressure eviction
**Estimate**: 4-5 days
- Task: Replace no-op stubs with tiered cache eviction policy.
- Task: Distinguish preview cache vs thumbnail cache priorities.
- Task: Add telemetry for evicted bytes, hit/miss, churn.

### Story E3-S2: Pipeline modularization
**Estimate**: 5-7 days
- Task: Extract `ImagePipeline` into stage modules:
  - input decode
  - global adjustments
  - local node rendering
  - AI compositing
  - output transform
- Task: Add stage-level benchmarks.

### Story E3-S3: Large-library responsiveness
**Estimate**: 3-4 days
- Task: Add backpressure for scan/thumbnail queue.
- Task: Tune preload windows based on viewport and mode (grid/single).

---

## Epic E4: UX/Feature Surface Alignment (P1/P2)
**Target**: Week 6-8  
**Estimate**: 8-11 days

### Story E4-S1: Resolve placeholder entry points
**Estimate**: 2-3 days
- Task: Implement or hide `Devices` and `Recent Imports` actions behind feature flags.
- Task: Add QA checklist for no dead-end navigation.

### Story E4-S2: Smart Collection rule completion
**Estimate**: 2-3 days
- Task: Implement functional capture-date filtering rule.
- Task: Add test matrix (timezone boundaries, missing EXIF).

### Story E4-S3: Capability/docs/release-note alignment
**Estimate**: 4-5 days
- Task: Add “implemented capability checklist” to release prep.
- Task: Block release-note claims without code/test evidence links.

---

## Epic E5: Release and Operational Hardening (P1)
**Target**: Week 8-10  
**Estimate**: 7-10 days

### Story E5-S1: CI release workflow integrity
**Estimate**: 3-4 days
- Task: Remove placeholder signing/comment-only steps.
- Task: Add assertive checks for Sparkle signature generation and appcast update.

### Story E5-S2: Observability and runbook
**Estimate**: 2-3 days
- Task: Consolidate signposts and e2e status into upgrade dashboard.
- Task: Add incident runbook for release rollback and sidecar migration failures.

### Story E5-S3: Upgrade acceptance pack
**Estimate**: 2-3 days
- Task: Bundle smoke tests, golden tests, and manual checklist for go/no-go.

---

## 6) Milestone Plan

### M1 (End of Week 3): Correctness Gate
- E1 complete.
- Exit criteria:
  - Render parity suite green.
  - AI edits visible in both preview/export.

### M2 (End of Week 5): Data and Memory Gate
- E2 + E3-S1 complete.
- Exit criteria:
  - No stale recipe regression.
  - Memory-pressure test stable.

### M3 (End of Week 8): Product Consistency Gate
- E3 + E4 complete.
- Exit criteria:
  - No placeholder UX in production.
  - Smart Collection date rules validated.

### M4 (End of Week 10): Release Hardening Gate
- E5 complete.
- Exit criteria:
  - Signed release workflow deterministic.
  - Runbook + acceptance pack approved.

---

## 7) Risk Register

1. **Schema drift risk**  
Mitigation: versioned sidecar migration tests + compatibility fixtures.

2. **Performance regression while modularizing pipeline**  
Mitigation: lock benchmark baseline before refactor; enforce budget thresholds.

3. **UI regressions during AppState decomposition**  
Mitigation: facade API + snapshot/UI smoke suite.

4. **Feature ambiguity (implemented vs planned)**  
Mitigation: release checklist with code/test evidence links.

---

## 8) Recommended Execution Order

1. Execute E1 immediately (render contract + AI integration).  
2. Start E2-S1 in parallel once E1-S1 interface is stable.  
3. Begin E3-S1 after first parity gate to avoid mixed root-cause debugging.  
4. Delay UX surface changes (E4) until correctness and memory behavior are stable.  
5. Close with E5 to lock release discipline.

---

## 9) Tracking Template (for sprint board)

Use these labels:
- `P0-correctness`
- `P1-reliability`
- `P2-polish`
- `render-parity`
- `schema-migration`
- `release-hardening`

Each task ticket should include:
- Impacted files/modules
- Test plan (unit/integration/ui)
- Rollback strategy
- Metrics affected

