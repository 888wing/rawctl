# State Management & UX Optimization Design

**Date**: 2026-01-08
**Status**: Approved
**Scope**: Loading states, empty states, error states across all app areas

## Overview

Comprehensive state management system for rawctl photo editing app, covering AI features, core editing, and account system with functional-oriented styling approach.

## Design Decisions

### Scope
- **State Types**: Loading, Empty, Error (all types)
- **Coverage**: Full coverage across AI features, core editing, account system
- **Visual Style**: Functional-oriented (branded for AI, system for general)
- **Error Handling**: Mixed strategy based on severity

### Existing Components (Keep)
- `NanoBananaProgressView` - Already well-designed AI processing overlay
- `NanoBananaResolutionPicker` - Resolution selection popover

### Components to Extend
- `ToastHUD` - Add actionable toasts and AI-specific styling

### New Components
- `EmptyStateView` - Configurable empty state
- `NetworkErrorBanner` - Top slide-in error banner
- `ErrorHandler` - Unified error handling service

## Component Specifications

### 1. EmptyStateView

```swift
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (label: String, action: () -> Void)? = nil
    var style: EmptyStateStyle = .standard

    enum EmptyStateStyle {
        case standard  // System gray
        case branded   // Orange-yellow gradient for AI features
    }
}
```

**Usage Locations**:
- PhotoGridView (no photos)
- SingleView (no photo selected)
- AccountView (not signed in)
- CreditsView (no credits)

### 2. ToastHUD Extensions

```swift
// New toast type for AI operations
enum ToastType {
    case info, success, warning, error
    case ai  // NEW: Orange-yellow branded style
}

// Actionable toast with retry support
struct ActionableToast: View {
    let message: String
    let type: ToastType
    let action: (label: String, action: () -> Void)?
}
```

### 3. NetworkErrorBanner

```swift
struct NetworkErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    // Auto-dismiss after 10 seconds
}
```

**Features**:
- Top slide-in animation
- Retry and dismiss buttons
- Auto-dismiss after 10 seconds
- Red accent color

### 4. ErrorHandler

```swift
enum ErrorSeverity {
    case fatal       // → Blocking alert dialog
    case recoverable // → ActionableToast with retry
    case warning     // → Standard toast
    case info        // → Brief toast
}

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    @Published var currentBanner: BannerError?
    @Published var currentToast: ToastMessage?
    @Published var fatalAlert: AlertError?

    func handle(_ error: Error, context: String = "")
}
```

## Error Handling Flow

```
User Action
    ↓
Service Layer (AccountService, NanoBananaService)
    ↓ throws Error
ErrorHandler.handle(error)
    ↓ severity check
┌─────────────────┬─────────────────┬─────────────────┐
│    .fatal       │  .recoverable   │ .warning/.info  │
│   AlertError    │  BannerError    │  ToastMessage   │
│   (blocking)    │  (with retry)   │  (auto-dismiss) │
└─────────────────┴─────────────────┴─────────────────┘
```

## File Structure

```
rawctl/Components/StateViews/
├── EmptyStateView.swift
├── NetworkErrorBanner.swift
├── LoadingOverlay.swift
└── ErrorHandler.swift

rawctl/Components/
├── ToastHUD.swift            (extend)
├── NanoBananaProgressView.swift (keep)
└── QuickActionsBar.swift     (keep)
```

## Implementation Priority

| Priority | Component | Reason |
|----------|-----------|--------|
| P0 | ErrorHandler | Foundation for others |
| P0 | ToastHUD extension | Most common feedback |
| P1 | EmptyStateView | Empty state UX |
| P1 | NetworkErrorBanner | Network error visibility |
| P2 | LoadingOverlay | Long operations |
| P2 | View integrations | Actual usage |

## Integration Points

### EmptyStateView
- `PhotoGridView` - No photos
- `SingleView` - No photo selected
- `AccountView` - Not signed in (branded)
- `CreditsView` - No credits (branded)

### NetworkErrorBanner
- `ContentView` top layer with `NetworkMonitor`

### ActionableToast
| Scenario | Type | Has Action |
|----------|------|------------|
| Export success | `.success` | No |
| Settings saved | `.success` | No |
| AI complete | `.ai` | "View" |
| Network temp fail | `.warning` | "Retry" |
| File format error | `.error` | No |
| Session expired | `.warning` | "Sign In" |
