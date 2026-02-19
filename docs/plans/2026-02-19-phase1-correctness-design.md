# rawctl Phase 1 Technical Design: Correctness First
**Date**: 2026-02-19
**Scope**: E1 + E2-S1 from vNext master plan
**Target Window**: Week 1-3
**Status**: Ready for implementation

---

## 1) Problem Statement

Current system behavior indicates a gap between stored edit data and rendering contracts:
- App state and sidecar include AI-related edit information.
- Preview/export pipeline contracts are primarily recipe + local nodes.

Goal of Phase 1:
- Define one render contract used by both preview and export.
- Ensure AI edits/layers and local adjustments are all reflected consistently.
- Remove stale-state risk in incremental refresh.

---

## 2) Design Goals

1. **Single source of render truth**: one context object for all render entry points.
2. **Parity by construction**: preview/export share the same stage graph.
3. **Backward compatible sidecar**: legacy sidecars still decode without data loss.
4. **Deterministic ordering**: local nodes and AI layers have explicit order rules.

---

## 3) Proposed Architecture

## 3.1 Unified Render Contract

Introduce:

```swift
struct RenderContext: Equatable {
    let assetId: String
    let recipe: EditRecipe
    let localNodes: [ColorNode]
    let aiLayers: [PhotoLayer]
    let aiEdits: [AIEdit]
    let colorProfile: RenderColorProfile
    let outputIntent: OutputIntent
}
```

Notes:
- `RenderContext` is immutable at pipeline boundary.
- Both preview and export call the same rendering stage entry with different `OutputIntent`.

## 3.2 Shared Pipeline Stage Order

```
Decode/Input
  -> Global Adjustments
  -> Local Nodes
  -> AI Layer Compositing
  -> Output Transform (preview/export intent)
```

Rules:
- Local nodes apply in list order.
- AI layers apply in stack order, with stable tie-breaker by creation timestamp.
- Disabled layers/nodes are skipped, but state is preserved.

## 3.3 Incremental Refresh Cleanup Fix

Current risk pattern:
- Assets are mutated before stale recipe keys are computed.

Fix:
1. Snapshot existing asset IDs and recipe keys.
2. Compute deleted/moved set first.
3. Remove corresponding recipe/local/AI states atomically.
4. Apply refreshed assets list.

---

## 4) Data Model and Migration

## 4.1 Sidecar Schema Versioning

Add explicit AI render section in sidecar payload (if not already normalized):

```swift
struct SidecarFile {
    var schemaVersion: Int
    var recipe: EditRecipe
    var localNodes: [ColorNode]?
    var aiLayers: [PhotoLayer]?
    var aiEdits: [AIEdit]?
}
```

Compatibility rules:
- Missing `aiLayers`/`aiEdits` decodes as empty arrays.
- Unknown future fields ignored on decode where possible.
- Save path writes current schema with full fields.

## 4.2 Migration Strategy

- **Read**: vN sidecars decode into latest in-memory model.
- **Write**: first non-noop edit upgrades sidecar to latest schema.
- **Roundtrip test**: old fixture -> decode -> encode -> decode must preserve semantics.

---

## 5) API Changes

## 5.1 ImagePipeline API (target shape)

```swift
func renderPreview(context: RenderContext, size: CGSize) async throws -> CIImage
func renderForExport(context: RenderContext, options: ExportOptions) async throws -> CIImage
```

Deprecate legacy overloads:
- Keep temporary forwarding wrappers for one sprint.
- Add warning logs when old signatures are used.
- Remove wrappers in next milestone after migration.

## 5.2 AppState Integration

Responsibilities:
- Build `RenderContext` from selected asset state.
- Ensure preview/export invoke identical context generation path.
- Invalidate preview only when context hash changes.

---

## 6) Testing Plan

## 6.1 Unit Tests

1. `RenderContextBuilderTests`
- Builds context with/without AI data.
- Stable hashing when semantic data unchanged.

2. `LayerCompositingOrderTests`
- Verifies deterministic order.
- Verifies disabled/hidden layer behavior.

3. `IncrementalRefreshCleanupTests`
- Delete/move/rename scenarios remove stale edit data correctly.

4. `SidecarMigrationTests`
- Legacy fixture decode and upgrade path.
- Roundtrip parity.

## 6.2 Integration Tests

1. `PreviewExportParityTests`
- Golden fixture set with local nodes + AI layers.
- Compare output using pixel diff tolerance.

2. `LargeBatchRefreshTests`
- 1k+ assets refresh cycle with edit-state churn.
- Assert no orphan recipe keys.

## 6.3 CI Gates

- New required check: `render-parity`.
- New required check: `sidecar-migration`.

---

## 7) Rollout Plan

### Step A (2-3 days)
- Introduce `RenderContext`.
- Add adapter wrappers to preserve current call sites.

### Step B (3-4 days)
- Port preview path to `RenderContext`.
- Add baseline parity tests.

### Step C (3-4 days)
- Port export path to `RenderContext`.
- Enable AI compositing in shared stage graph.

### Step D (2-3 days)
- Fix incremental refresh cleanup ordering.
- Add stale-state regression tests.

### Step E (1-2 days)
- Remove dead code paths and stabilize logs/metrics.

---

## 8) Acceptance Criteria (Phase 1 Exit)

1. Preview and export use the same render contract.
2. AI layers/edits visibly affect preview and export outputs.
3. No stale recipe/local/AI states after asset delete/move/rename test scenarios.
4. Render parity + sidecar migration CI checks are green.
5. No breaking load of existing sidecar files.

---

## 9) Open Decisions

1. AI compositing policy:
- Option A: fully flattened into final stage each render (simpler, slower).
- Option B: cached layer composites with invalidation map (faster, more complex).

2. Context hash granularity:
- Include only semantic fields or all persisted fields (metadata noise tradeoff).

3. Export fidelity policy:
- Strict parity with preview vs export-specific color transform allowances.

Recommendation for Phase 1:
- Choose Option A for compositing first to minimize correctness risk.
- Optimize in Phase 2 after parity is stable.

