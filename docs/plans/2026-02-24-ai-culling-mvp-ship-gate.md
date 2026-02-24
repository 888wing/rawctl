# AI Culling MVP Ship Gate — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix the 4 blockers that prevent shipping AI Culling as a stable v1.1 feature.

**Architecture:** Pure Swift/Vision, no schema migration, no new dependencies. Fixes are
surgical: test module name, group-aware duplicate selection, pre-culling undo snapshot,
and thumbnail load deduplication. AppState/SidecarService wiring remains unchanged.

**Tech Stack:** Swift 5.9, Vision framework, Swift Testing (`@Test`), CoreImage, Xcode 16

---

## Context (read before touching code)

| File | Key location | Issue |
|------|-------------|-------|
| [rawctlTests/CullingServiceTests.swift](rawctlTests/CullingServiceTests.swift#L13) | Line 13 | `@testable import rawctl` → should be `Latent` (PRODUCT_NAME = Latent in project.pbxproj:432) |
| [rawctl/Services/CullingService.swift](rawctl/Services/CullingService.swift#L215) | Lines 215-228 | `detectDuplicate` returns `Bool` — rejects ALL photos in a burst |
| [rawctl/Services/CullingService.swift](rawctl/Services/CullingService.swift#L240) | Line 241 | `case (true, _): (rating, flag) = (0, .reject)` — no representative check |
| [rawctl/Models/AppState.swift](rawctl/Models/AppState.swift#L1026) | Lines 1026-1040 | `applyCullingResults` overwrites rating/flag with no rollback |
| [rawctl/Services/CullingService.swift](rawctl/Services/CullingService.swift#L73) | Lines 73, 85 | Thumbnail loaded twice per photo (phase 1 + phase 2) |

**Test command (use throughout):**
```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingServiceTests \
  2>&1 | tail -30
```

---

## Task 1: Fix test module import

**Files:**
- Modify: `rawctlTests/CullingServiceTests.swift:13`

### Step 1: Run tests to confirm the current failure

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingServiceTests \
  2>&1 | grep -E "error:|FAILED|PASSED" | head -10
```
Expected: compile error — `unable to find module 'rawctl'`

### Step 2: Fix the import

In `rawctlTests/CullingServiceTests.swift` line 13, change:
```swift
@testable import rawctl
```
to:
```swift
@testable import Latent
```

### Step 3: Verify tests compile and pass

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingServiceTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:" | head -20
```
Expected: all existing tests pass (no failures).

### Step 4: Check if any other test files have the same import

```bash
grep -rn "@testable import rawctl" rawctlTests/
```
Fix any additional occurrences with the same replacement.

### Step 5: Commit

```bash
git add rawctlTests/
git commit -m "fix(tests): correct @testable import module name rawctl → Latent"
```

---

## Task 2: Group-aware duplicate detection (keep best in burst)

**Files:**
- Modify: `rawctl/Services/CullingService.swift` (full rewrite of duplicate logic)
- Modify: `rawctlTests/CullingServiceTests.swift` (new tests)

This is the core bug: a burst of 5 identical shots currently all get `(0, .reject)`. After
this task, only the 4 non-representatives get rejected; the best shot keeps its score.

### Step 1: Write failing tests first

Add these tests to `rawctlTests/CullingServiceTests.swift`, inside `struct CullingServiceTests`:

```swift
// MARK: - Duplicate group logic

@Test func duplicateBurstKeepsRepresentative() {
    // Simulate a group of 3 "duplicates": only the non-representative should be rejected.
    // We test computeFinalScore indirectly via the public CullingScore struct.
    // Representative (isGroupRepresentative = true): should NOT become reject
    let rep = makeCullingScoreGroupAware(sharpness: 0.9, saliency: 0.8,
                                          groupId: UUID(), isRepresentative: true)
    #expect(rep.suggestedFlag != .reject, "Representative must not be auto-rejected")
    #expect(rep.suggestedRating >= 4)

    // Non-representative: should become reject
    let nonRep = makeCullingScoreGroupAware(sharpness: 0.9, saliency: 0.8,
                                             groupId: UUID(), isRepresentative: false)
    #expect(nonRep.suggestedFlag == .reject)
    #expect(nonRep.suggestedRating == 0)
}

@Test func uniquePhotoIsNotRejectedByDuplicateLogic() {
    let unique = makeCullingScoreGroupAware(sharpness: 0.7, saliency: 0.6,
                                             groupId: nil, isRepresentative: true)
    #expect(unique.suggestedFlag != .reject)
}

// Add this helper alongside the existing makeCullingScore helper:
private func makeCullingScoreGroupAware(
    sharpness: Double,
    saliency: Double,
    groupId: UUID?,
    isRepresentative: Bool
) -> CullingScore {
    let combined = sharpness * 0.6 + saliency * 0.4
    let isDuplicateNonRep = groupId != nil && !isRepresentative
    let (rating, flag): (Int, Flag)
    switch (isDuplicateNonRep, combined) {
    case (true, _):    (rating, flag) = (0, .reject)
    case (_, ..<0.20): (rating, flag) = (0, .reject)
    case (_, ..<0.40): (rating, flag) = (1, .none)
    case (_, ..<0.55): (rating, flag) = (2, .none)
    case (_, ..<0.70): (rating, flag) = (3, .none)
    case (_, ..<0.85): (rating, flag) = (4, .pick)
    default:           (rating, flag) = (5, .pick)
    }
    return CullingScore(
        sharpness: sharpness,
        saliency: saliency,
        duplicateGroupId: groupId,
        isGroupRepresentative: isRepresentative,
        suggestedRating: rating,
        suggestedFlag: flag
    )
}
```

### Step 2: Run tests to confirm they fail

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingServiceTests \
  2>&1 | grep -E "error:|failed" | head -20
```
Expected: compile error — `CullingScore` has no `duplicateGroupId` or `isGroupRepresentative`.

### Step 3: Update CullingScore struct

In `rawctl/Services/CullingService.swift`, replace the entire `CullingScore` struct (lines 16–27):

```swift
/// Score produced for a single photo by the culling pass.
struct CullingScore: Sendable {
    /// Sharpness/focus quality, 0 (blurry) – 1 (sharp).
    let sharpness: Double
    /// Composition quality from attention saliency map, 0 – 1.
    let saliency: Double
    /// Non-nil when this photo belongs to a near-duplicate group.
    let duplicateGroupId: UUID?
    /// True if this photo is the chosen representative of its group (highest combined score).
    /// Always true for unique photos (duplicateGroupId == nil).
    let isGroupRepresentative: Bool
    /// Suggested star rating (0–5) derived from combined score.
    let suggestedRating: Int
    /// Suggested flag derived from combined score.
    let suggestedFlag: Flag
}
```

### Step 4: Add group-building helper to CullingService

In `rawctl/Services/CullingService.swift`, replace the entire `detectDuplicate` method (lines 215–228) with these two new methods:

```swift
/// Build duplicate groups from feature prints using pairwise distance.
/// Returns a dict mapping assetId → (groupId, isRepresentative).
/// Photos with no near-duplicates map to (nil, true).
private func buildDuplicateGroups(
    prints: [UUID: VNFeaturePrintObservation],
    scores: [UUID: (sharpness: Double, saliency: Double)]
) -> [UUID: (groupId: UUID?, isRepresentative: Bool)] {
    // Union-Find: parent[id] = id means it's a root.
    var parent: [UUID: UUID] = Dictionary(uniqueKeysWithValues: prints.keys.map { ($0, $0) })

    func find(_ id: UUID) -> UUID {
        var id = id
        while parent[id] != id { id = parent[id] ?? id }
        return id
    }

    func union(_ a: UUID, _ b: UUID) {
        let ra = find(a), rb = find(b)
        if ra != rb { parent[ra] = rb }
    }

    // Pair-wise distance; O(n²) acceptable for typical burst sizes (<200 shots).
    let ids = Array(prints.keys)
    for i in 0..<ids.count {
        guard let pi = prints[ids[i]] else { continue }
        for j in (i + 1)..<ids.count {
            guard let pj = prints[ids[j]] else { continue }
            var distance: Float = 0
            if (try? pi.computeDistance(&distance, to: pj)) != nil,
               distance < duplicateDistanceThreshold {
                union(ids[i], ids[j])
            }
        }
    }

    // Collect groups: root → [members]
    var groups: [UUID: [UUID]] = [:]
    for id in ids {
        let root = find(id)
        groups[root, default: []].append(id)
    }

    // Assign representative per group (highest combined score).
    var result: [UUID: (groupId: UUID?, isRepresentative: Bool)] = [:]
    for (_, members) in groups {
        if members.count == 1 {
            // Unique photo — not a duplicate.
            result[members[0]] = (groupId: nil, isRepresentative: true)
        } else {
            let groupId = UUID()
            let rep = members.max(by: { a, b in
                let sa = (scores[a]?.sharpness ?? 0) * 0.6 + (scores[a]?.saliency ?? 0) * 0.4
                let sb = (scores[b]?.sharpness ?? 0) * 0.6 + (scores[b]?.saliency ?? 0) * 0.4
                return sa < sb
            })
            for member in members {
                result[member] = (groupId: groupId, isRepresentative: member == rep)
            }
        }
    }
    return result
}
```

### Step 5: Rewrite the score() method to use group-aware pipeline

Replace the entire `score()` function body (lines 59–99) with:

```swift
func score(
    assets: [PhotoAsset],
    onProgress: @escaping @Sendable (Int, Int) -> Void
) async -> [UUID: CullingScore] {
    guard !assets.isEmpty else { return [:] }

    let totalSteps = assets.count * 2

    // ── Phase 1: Feature prints + sharpness/saliency (single thumbnail load per photo) ──
    var featurePrints: [UUID: VNFeaturePrintObservation] = [:]
    var rawScores: [UUID: (sharpness: Double, saliency: Double)] = [:]
    featurePrints.reserveCapacity(assets.count)
    rawScores.reserveCapacity(assets.count)

    for (idx, asset) in assets.enumerated() {
        onProgress(idx, totalSteps)
        guard let image = loadThumbnail(for: asset) else { continue }
        if let fp = generateFeaturePrint(from: image) {
            featurePrints[asset.id] = fp
        }
        rawScores[asset.id] = (
            sharpness: scoreSharpness(image: image),
            saliency:  scoreSaliency(image: image)
        )
    }

    // ── Phase 2: Build groups, then compute final scores ──────────────────────────────
    let groups = buildDuplicateGroups(prints: featurePrints, scores: rawScores)

    var results: [UUID: CullingScore] = [:]
    results.reserveCapacity(assets.count)

    for (idx, asset) in assets.enumerated() {
        onProgress(assets.count + idx, totalSteps)
        guard let raw = rawScores[asset.id] else { continue }
        let group = groups[asset.id] ?? (groupId: nil, isRepresentative: true)
        results[asset.id] = computeFinalScore(
            sharpness: raw.sharpness,
            saliency:  raw.saliency,
            groupId:   group.groupId,
            isRepresentative: group.isRepresentative
        )
    }

    return results
}
```

### Step 6: Update computeFinalScore signature and logic

Replace `computeFinalScore` (lines 232–257):

```swift
private func computeFinalScore(
    sharpness: Double,
    saliency: Double,
    groupId: UUID?,
    isRepresentative: Bool
) -> CullingScore {
    let combined = sharpness * 0.6 + saliency * 0.4
    let isNonRepDuplicate = groupId != nil && !isRepresentative

    let (rating, flag): (Int, Flag)
    switch (isNonRepDuplicate, combined) {
    case (true, _):      (rating, flag) = (0, .reject)
    case (_, ..<0.20):   (rating, flag) = (0, .reject)
    case (_, ..<0.40):   (rating, flag) = (1, .none)
    case (_, ..<0.55):   (rating, flag) = (2, .none)
    case (_, ..<0.70):   (rating, flag) = (3, .none)
    case (_, ..<0.85):   (rating, flag) = (4, .pick)
    default:             (rating, flag) = (5, .pick)
    }

    return CullingScore(
        sharpness: sharpness,
        saliency:  saliency,
        duplicateGroupId: groupId,
        isGroupRepresentative: isRepresentative,
        suggestedRating: rating,
        suggestedFlag:   flag
    )
}
```

### Step 7: Remove the now-unused detectDuplicate method

Delete the old `detectDuplicate(assetId:in:)` method entirely (it's replaced by `buildDuplicateGroups`).

### Step 8: Update the existing test helper to use new struct shape

The existing `makeCullingScore` helper in `CullingServiceTests.swift` still uses `isDuplicate: Bool`. Update it to match the new struct:

```swift
private func makeCullingScore(
    sharpness: Double,
    saliency: Double,
    isDuplicate: Bool   // kept for backward compat — maps to non-representative duplicate
) -> CullingScore {
    let combined = sharpness * 0.6 + saliency * 0.4
    let groupId: UUID? = isDuplicate ? UUID() : nil
    let isRep = !isDuplicate
    let (rating, flag): (Int, Flag)
    switch (isDuplicate, combined) {
    case (true, _):    (rating, flag) = (0, .reject)
    case (_, ..<0.20): (rating, flag) = (0, .reject)
    case (_, ..<0.40): (rating, flag) = (1, .none)
    case (_, ..<0.55): (rating, flag) = (2, .none)
    case (_, ..<0.70): (rating, flag) = (3, .none)
    case (_, ..<0.85): (rating, flag) = (4, .pick)
    default:           (rating, flag) = (5, .pick)
    }
    return CullingScore(
        sharpness: sharpness,
        saliency:  saliency,
        duplicateGroupId: groupId,
        isGroupRepresentative: isRep,
        suggestedRating: rating,
        suggestedFlag: flag
    )
}
```

### Step 9: Run tests

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingServiceTests \
  2>&1 | grep -E "passed|failed|error:" | head -20
```
Expected: all tests pass including the new group-aware tests.

### Step 10: Commit

```bash
git add rawctl/Services/CullingService.swift rawctlTests/CullingServiceTests.swift
git commit -m "fix(culling): group-aware duplicate detection — keep best in burst, reject rest"
```

---

## Task 3: Add pre-culling undo snapshot

**Files:**
- Modify: `rawctl/Models/AppState.swift` (around lines 992–1040)

Without this, running AI Cull on an already-rated library silently overwrites all manual work.

### Step 1: Write a failing test in a new file

Create `rawctlTests/CullingUndoTests.swift`:

```swift
//
//  CullingUndoTests.swift
//  rawctlTests
//
import Foundation
import Testing
@testable import Latent

@MainActor
struct CullingUndoTests {

    @Test func cullingUndoSnapshotCapturesExistingRatings() {
        // Given an AppState with a recipe that has rating=3
        let state = AppState()
        let assetId = UUID()
        var recipe = EditRecipe()
        recipe.rating = 3
        recipe.flag = .pick
        state.recipes[assetId] = recipe

        // When we capture the pre-cull snapshot
        let snapshot = state.capturePreCullSnapshot()

        // Then it should contain the existing rating and flag
        #expect(snapshot[assetId]?.rating == 3)
        #expect(snapshot[assetId]?.flag == .pick)
    }

    @Test func cullingUndoRestoresRatings() {
        let state = AppState()
        let assetId = UUID()
        var original = EditRecipe()
        original.rating = 4
        original.flag = .pick
        state.recipes[assetId] = original

        let snapshot = state.capturePreCullSnapshot()

        // Simulate culling overwriting the rating
        var culledRecipe = EditRecipe()
        culledRecipe.rating = 0
        culledRecipe.flag = .reject
        state.recipes[assetId] = culledRecipe

        // Undo should restore
        state.restorePreCullSnapshot(snapshot)
        #expect(state.recipes[assetId]?.rating == 4)
        #expect(state.recipes[assetId]?.flag == .pick)
    }
}
```

### Step 2: Run test to confirm it fails

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingUndoTests \
  2>&1 | grep -E "error:|failed" | head -10
```
Expected: compile error — `capturePreCullSnapshot` and `restorePreCullSnapshot` don't exist.

### Step 3: Add snapshot type and stored property to AppState

In `rawctl/Models/AppState.swift`, find the `// MARK: - AI Culling` section (around line 992).

Add just above `func startAICulling()`:

```swift
/// Stores rating+flag per asset captured immediately before an AI cull run.
/// Used by "Undo AI Cull" to restore manually set metadata.
typealias PreCullSnapshot = [UUID: (rating: Int, flag: Flag)]

/// The most recent pre-cull snapshot. Cleared when user dismisses or starts a new cull.
var lastPreCullSnapshot: PreCullSnapshot? = nil

/// Capture current rating + flag for every loaded asset.
func capturePreCullSnapshot() -> PreCullSnapshot {
    var snap = PreCullSnapshot()
    for (id, recipe) in recipes {
        snap[id] = (rating: recipe.rating, flag: recipe.flag)
    }
    return snap
}

/// Restore rating + flag from a previously captured snapshot.
/// Does NOT touch any other recipe fields (exposure, crop, etc.).
func restorePreCullSnapshot(_ snapshot: PreCullSnapshot) {
    for (id, saved) in snapshot {
        guard recipes[id] != nil else { continue }
        recipes[id]?.rating = saved.rating
        recipes[id]?.flag   = saved.flag
    }
    lastPreCullSnapshot = nil
}
```

### Step 4: Wire snapshot capture into startAICulling

In `startAICulling()`, add one line immediately after `guard !assets.isEmpty, !cullingProgress.isRunning else { return }`:

```swift
lastPreCullSnapshot = capturePreCullSnapshot()
```

The full updated guard block looks like:

```swift
guard !assets.isEmpty, !cullingProgress.isRunning else { return }
lastPreCullSnapshot = capturePreCullSnapshot()   // ← add this line

cullingAutoHideTask?.cancel()
```

### Step 5: Run undo tests

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:rawctlTests/CullingUndoTests \
  2>&1 | grep -E "passed|failed|error:" | head -10
```
Expected: both undo tests pass.

### Step 6: Run full test suite

```bash
xcodebuild test -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "Test Suite.*passed|Test Suite.*failed" | head -5
```
Expected: no failures.

### Step 7: Commit

```bash
git add rawctl/Models/AppState.swift rawctlTests/CullingUndoTests.swift
git commit -m "feat(culling): capture pre-cull snapshot for undo; wire into startAICulling"
```

---

## Task 4: Eliminate double thumbnail load

**Files:**
- Modify: `rawctl/Services/CullingService.swift`

This was already fixed as part of Task 2 (Phase 1 now loads thumbnail once and scores sharpness +
saliency in the same pass). Verify it explicitly.

### Step 1: Confirm thumbnail load is now single-pass

Search the updated `score()` method for calls to `loadThumbnail`:

```bash
grep -n "loadThumbnail" rawctl/Services/CullingService.swift
```
Expected: exactly **one** call site (inside the `for (idx, asset) in assets` loop of the unified phase).

If there are still two calls, re-check Task 2 Step 5 was applied correctly.

### Step 2: Commit (if any residual fix needed)

```bash
git add rawctl/Services/CullingService.swift
git commit -m "perf(culling): single thumbnail load per photo (was two passes)"
```

---

## Task 5: Run full build + test suite — confirm ship gate

### Step 1: Clean build

```bash
xcodebuild build \
  -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | head -10
```
Expected: `BUILD SUCCEEDED`

### Step 2: Full unit test run

```bash
xcodebuild test \
  -project rawctl.xcodeproj \
  -scheme rawctl \
  -destination 'platform=macOS,arch=arm64' \
  2>&1 | grep -E "Test Suite.*passed|Test Suite.*failed|error:" | head -10
```
Expected: `Test Suite 'All tests' passed`

### Step 3: Manual smoke test checklist

1. Open app, load a folder with 10+ photos including burst shots.
2. Run AI Cull (requires Pro).
3. Verify: burst shots — only 1 photo per burst is NOT rejected.
4. Verify: non-burst photos score normally (not all rejected).
5. Verify: `lastPreCullSnapshot` is non-nil after cull (check in Xcode debugger or add a print).
6. Call `restorePreCullSnapshot` via debugger — confirm ratings restored.

### Step 4: Tag ship gate as verified

```bash
git tag culling-mvp-ship-gate-v1
```

### Step 5: Play completion sound

```bash
afplay /System/Library/Sounds/Glass.aiff
```

---

## What this plan does NOT do (out of scope for this gate)

These are valid v1.1+ items from the backlog but not needed to ship:

- `CullingAnalysis` struct with full sidecar persistence (E3-S1)
- Exposure scoring histogram (E1-S1)
- Explainability UI labels in GridView (E4-S1)
- Stage 2/3 protocol stubs (E6-S1)
- "Undo AI Cull" button in GridView (can be a follow-up ticket using `lastPreCullSnapshot`)

---

## Estimated effort

| Task | Effort |
|------|--------|
| 1 — Fix module import | 5 min |
| 2 — Group-aware duplicates | 2–3 h |
| 3 — Undo snapshot | 1 h |
| 4 — Single thumbnail load | 0 min (done in Task 2) |
| 5 — Ship gate verification | 30 min |
| **Total** | **~4 h** |
