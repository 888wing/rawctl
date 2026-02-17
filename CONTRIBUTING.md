# Contributing to rawctl

Thank you for your interest in contributing to rawctl! This document provides guidelines and information for contributors.

## Development Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Basic understanding of SwiftUI and Core Image

### Getting Started

```bash
# Clone the repository
git clone https://github.com/yourname/rawctl.git
cd rawctl/rawctl

# Open in Xcode
open rawctl.xcodeproj

# Build and run
# Press ⌘R in Xcode
```

## Project Structure

### Models (`rawctl/Models/`)

| File | Purpose |
|------|---------|
| `PhotoAsset.swift` | Represents a photo file with metadata |
| `EditRecipe.swift` | Non-destructive editing parameters |
| `ExportSettings.swift` | JPG export configuration |
| `AppState.swift` | Global observable state |

### Views (`rawctl/Views/`)

| File | Purpose |
|------|---------|
| `MainLayoutView.swift` | Root NavigationSplitView layout |
| `SidebarView.swift` | Left panel - folder browser |
| `WorkspaceView.swift` | Center - Grid/Single toggle |
| `SingleView.swift` | Photo preview with crop overlay |
| `InspectorView.swift` | Right panel - adjustment sliders |
| `ExportDialog.swift` | Export settings sheet |

### Services (`rawctl/Services/`)

All services are implemented as `actor` types for thread safety:

| File | Purpose |
|------|---------|
| `ImagePipeline.swift` | Core Image rendering with RAW support |
| `SidecarService.swift` | JSON sidecar file I/O |
| `ExportService.swift` | Background JPG export |
| `ThumbnailService.swift` | Thumbnail generation and caching |
| `FileSystemService.swift` | Folder scanning |
| `MemoryCardService.swift` | SD card detection |

## Key Concepts

### True RAW Processing

The app uses `CIRAWFilter` for true RAW processing. Critical adjustments are applied at the RAW decode level:

```swift
// In ImagePipeline.swift
private func applyRecipeToRAWFilter(_ filter: CIFilter, recipe: EditRecipe) {
    // Exposure applied directly to RAW
    filter.setValue(recipe.exposure, forKey: kCIInputEVKey)
    
    // Shadow recovery from sensor data
    rawFilter.setValue(shadowBoost, forKey: "inputBoostShadowAmount")
}
```

### Non-Destructive Editing

All edits are stored in sidecar JSON files, never modifying the original:

```
photo.ARW           # Original (never modified)
photo.ARW.rawctl.json  # Edit recipe (JSON)
```

### State Management

`AppState` uses a per-photo recipes dictionary:

```swift
@Published var recipes: [UUID: EditRecipe] = [:]

var currentRecipe: EditRecipe {
    get { recipes[selectedAssetId] ?? EditRecipe() }
    set { recipes[selectedAssetId] = newValue }
}
```

## Code Guidelines

### SwiftUI Views

- Use `@ObservedObject` for shared state
- Use `@State` for local view state
- Prefer computed properties over stored state when possible

```swift
struct MyView: View {
    @ObservedObject var appState: AppState
    @State private var localValue = 0
    
    var body: some View {
        // ...
    }
}
```

### Actors for Services

All services should be actors for thread safety:

```swift
actor MyService {
    static let shared = MyService()
    
    func doWork() async -> Result {
        // Thread-safe implementation
    }
}
```

### Async/Await

Prefer `async/await` over completion handlers:

```swift
// ✅ Good
func loadImage() async -> NSImage? {
    await ImagePipeline.shared.renderPreview(...)
}

// ❌ Avoid
func loadImage(completion: @escaping (NSImage?) -> Void) {
    // ...
}
```

## Testing

### Running Tests

```bash
# In Xcode
# Press ⌘U to run all tests
```

### Test Coverage Areas

- [ ] Model serialization (EditRecipe ↔ JSON)
- [ ] Sidecar read/write
- [ ] Image pipeline rendering
- [ ] Export functionality

## Adding New Features

### Adding a New Adjustment

1. Add property to `EditRecipe.swift`:
   ```swift
   var myNewAdjustment: Double = 0.0
   ```

2. Add UI in `InspectorView.swift`:
   ```swift
   ControlSlider(
       label: "My Adjustment",
       value: $localRecipe.myNewAdjustment,
       range: -100...100
   )
   ```

3. Apply in `ImagePipeline.swift`:
   ```swift
   if recipe.myNewAdjustment != 0 {
       // Apply CIFilter
   }
   ```

4. Update `hasEdits` computed property if needed

### Adding a New CIFilter

```swift
private func applyMyFilter(_ recipe: EditRecipe, to image: CIImage) -> CIImage {
    guard let filter = CIFilter(name: "CIMyFilter") else {
        return image
    }
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(recipe.myValue, forKey: "inputMyParameter")
    return filter.outputImage ?? image
}
```

## Pull Request Process

1. **Fork & Branch**: Create a feature branch from `main`
2. **Develop**: Make your changes with clear commits
3. **Test**: Ensure the app builds and runs correctly
4. **Document**: Update README if adding features
5. **PR**: Open a pull request with description

### PR Checklist

- [ ] Code builds without warnings
- [ ] New features are documented
- [ ] Follows existing code style
- [ ] Tested manually with various RAW files

## Known Issues

- Histogram shows placeholder data (not implemented)
- Crop aspect ratio enforcement not fully implemented
- Large folders (2000+ images) may be slow to load

## Questions?

Open an issue on GitHub for any questions or discussions.
