# Latent Sidebar + Startup Optimization Report
Date: 2026-02-19
Scope: Sidebar entry-point convergence, startup restore consistency, recent-folder UX

## What Changed
- Unified folder-opening path behind `AppState`:
  - `openFolderFromPicker()`
  - `openFolder(at:registerInFolderHistory:)`
  - `openFolderFromPath(_:registerInFolderHistory:)`
- Rewired all UI/menu entry points to use the same open-folder pipeline:
  - File menu `Open Folder…`
  - Workspace empty state `Open Folder…`
  - Grid empty state `Open Folder`
  - Sidebar `Open Folder…`, saved folders, and path input
- Added File menu `Open Recent` with `Clear Menu`.
- Added Sidebar `Recent` list under legacy browse section.

## Startup Restore Rules (Now Explicit)
Order:
1. Last opened project (catalog v2 restore path).
2. Default folder (`FolderManager` default source).
3. Last opened folder (`latent.lastOpenedFolder`).

Behavior:
- If project restore fails, app falls back to folder startup restore.
- If default-folder restore fails, app falls back to last-opened folder.

## Persistence and Migration
- Folder persistence keys moved to `latent.*` namespace:
  - `latent.folderSources`
  - `latent.recentFolders`
  - `latent.lastOpenedFolder`
- Backward compatibility:
  - Auto-migrate `rawctl.folderSources` and `rawctl.recentFolders` into `latent.*` when missing.
  - Auto-migrate legacy `lastOpenedFolder` to `latent.lastOpenedFolder`.
  - Legacy `defaultFolderPath` is migrated into `FolderManager` default source (then cleared on success).

## Security-Scoped Bookmark Lifecycle
- Added active scoped URL tracking in `FolderManager`.
- On folder switch:
  - Previous scoped access is released.
  - New folder bookmark is resolved (refresh stale bookmark when needed) and access is started.
- On app termination:
  - Scoped access is explicitly ended.

## Sidebar State Persistence
- Sidebar expansion states now persist across relaunch:
  - `latent.sidebar.library.expanded`
  - `latent.sidebar.projects.expanded`
  - `latent.sidebar.smartCollections.expanded`
  - `latent.sidebar.devices.expanded`
  - `latent.sidebar.legacyFolders.expanded`

## Feature Flag Governance
- `AppFeatures` boolean parsing now accepts normalized truthy values:
  - `1`, `true`, `yes`, `on`, `enabled`
- Keeps existing dual-key compatibility for renamed envs:
  - `LATENT_ENABLE_*` and `RAWCTL_ENABLE_*`

## Verification Coverage Added
`rawctlTests/FolderStartupFlowTests.swift`:
- startup choice precedence (default folder vs last opened).
- legacy namespace migration (`rawctl.*` -> `latent.*`).
- recent-folder uniqueness and reorder behavior.
- AppState migration of legacy startup keys and folder registration path.

