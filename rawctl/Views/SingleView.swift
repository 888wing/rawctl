//
//  SingleView.swift
//  rawctl
//
//  Single photo view with preview and filmstrip
//

import SwiftUI

/// Single photo editing view
struct SingleView: View {
    @ObservedObject var appState: AppState
    @StateObject private var generationService = AIGenerationService.shared
    @State private var previewImage: NSImage?
    @State private var originalImage: NSImage?  // For Before/After
    @State private var showOriginal = false     // Before/After toggle
    @State private var isLoadingPreview = false
    @State private var imageViewSize: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero  // Base offset for cumulative panning
    @State private var isSliderDragging = false    // Track if user is dragging a slider
    @State private var isProcessingPreview = false // Track if preview is being rendered
    @State private var showAIEditor = false        // AI Editor sheet
    @State private var cropGridOverlay: GridOverlay = .thirds  // Crop grid overlay type
    @FocusState private var isFocused: Bool
    
    // Expose for histogram
    var currentPreviewImage: NSImage? { previewImage }
    
    private var currentCrop: Binding<Crop> {
        Binding(
            get: {
                if let id = appState.selectedAssetId {
                    return appState.recipes[id]?.crop ?? Crop()
                }
                return Crop()
            },
            set: { newValue in
                if let id = appState.selectedAssetId {
                    appState.recipes[id]?.crop = newValue
                    appState.saveCurrentRecipe()
                }
            }
        )
    }
    
    /// The image to display (original or edited)
    private var displayImage: NSImage? {
        showOriginal ? originalImage : previewImage
    }
    
    /// Zoom level display
    private var zoomPercentage: Int {
        Int(zoomScale * 100)
    }

    /// Returns the appropriate mask editor view for the currently-edited node.
    /// - Parameter imageSize: The size of the displayed image (for coordinate mapping).
    @ViewBuilder
    private func maskEditorOverlay(imageSize: CGSize) -> some View {
        if let nodeId = appState.editingMaskId,
           let nodeIndex = appState.currentLocalNodes.firstIndex(where: { $0.id == nodeId }) {
            let nodeBinding = Binding<ColorNode>(
                get: { appState.currentLocalNodes[nodeIndex] },
                set: { appState.updateLocalNode($0) }
            )
            if case .radial = appState.currentLocalNodes[nodeIndex].mask?.type {
                RadialMaskEditor(node: nodeBinding, imageSize: imageSize)
            } else if case .linear = appState.currentLocalNodes[nodeIndex].mask?.type {
                LinearMaskEditor(node: nodeBinding, imageSize: imageSize)
            } else if case .brush = appState.currentLocalNodes[nodeIndex].mask?.type {
                BrushMaskEditor(node: nodeBinding, appState: appState, imageSize: imageSize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Main preview area
                ZStack {
                    if appState.comparisonMode == .sideBySide {
                        HStack(spacing: 2) {
                            // Before
                            comparisonImageView(image: originalImage, label: "BEFORE")
                            
                            // After
                            comparisonImageView(image: previewImage, label: "AFTER")
                        }
                    } else {
                        MainImageView(
                            displayImage: displayImage,
                            isLoadingPreview: isLoadingPreview,
                            isProcessingPreview: isProcessingPreview,
                            showOriginal: showOriginal,
                            zoomScale: $zoomScale,
                            zoomOffset: $zoomOffset,
                            dragOffset: $dragOffset,
                            currentCrop: currentCrop,
                            gridOverlay: cropGridOverlay,
                            appState: appState,
                            geometry: geometry,
                            toggleZoom: toggleZoom
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }
                .focusable()
                .focused($isFocused)
                .overlay {
                    // Eyedropper interaction layer
                    if appState.eyedropperMode {
                        Color.black.opacity(0.001) // Transparent but clickable
                            .onTapGesture { location in
                                pickWhitePoint(at: location, in: geometry.size)
                            }
                            .onHover { inside in
                                if inside {
                                    NSCursor.crosshair.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }

                    // Mask painting overlay for AI region editing
                    if appState.maskPaintingMode, let image = displayImage {
                        VStack(spacing: 0) {
                            // Brush toolbar at top
                            BrushToolbar(
                                mask: appState.currentBrushMask,
                                onClear: { appState.currentBrushMask.clear() },
                                onUndo: { appState.currentBrushMask.undo() }
                            )

                            // Canvas overlay
                            MaskCanvasView(
                                mask: appState.currentBrushMask,
                                backgroundImage: image,
                                imageSize: image.size,
                                onMaskChanged: nil
                            )
                        }
                        .background(Color.black.opacity(0.3))
                    }

                    // AI Generation progress overlay
                    if generationService.state.isActive {
                        AIGenerationProgressOverlay(state: generationService.state)
                    }

                    // Mask editor overlay — shown when editing a local adjustment mask
                    if appState.editingMaskId != nil, appState.showMaskOverlay {
                        maskEditorOverlay(imageSize: previewImage?.size ?? CGSize(width: 1000, height: 1000))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    // Transform and AI Edit buttons
                    TransformToolbar(
                        transformMode: $appState.transformMode,
                        showAIEditor: $showAIEditor,
                        hasAsset: appState.selectedAsset != nil,
                        onEnterTransformMode: {
                            // Save history before crop changes for undo support
                            if let id = appState.selectedAssetId,
                               let recipe = appState.recipes[id] {
                                appState.pushHistory(recipe)
                            }
                        }
                    )
                }
                .overlay(alignment: .top) {
                    // Crop toolbar when in transform mode
                    if appState.transformMode, appState.selectedAsset != nil {
                        CropToolbar(
                            crop: currentCrop,
                            gridOverlay: $cropGridOverlay,
                            imageSize: previewImage?.size ?? CGSize(width: 1000, height: 1000),
                            onConfirm: {
                                // Enable crop when confirmed with changes
                                if currentCrop.wrappedValue.rect != CropRect() {
                                    currentCrop.wrappedValue.isEnabled = true
                                }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appState.transformMode = false
                                }
                            },
                            onCancel: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appState.transformMode = false
                                }
                            },
                            onReset: {
                                // Save history before reset for undo support
                                if let id = appState.selectedAssetId,
                                   let recipe = appState.recipes[id] {
                                    appState.pushHistory(recipe)
                                }
                                currentCrop.wrappedValue = Crop()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .overlay(alignment: .bottom) {
                    // Mask editing toolbar — shown when editing a local adjustment mask
                    if appState.editingMaskId != nil {
                        MaskEditingToolbar(appState: appState)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                
                // Info bar
                if let asset = appState.selectedAsset {
                    InfoBar(asset: asset, metadata: asset.metadata)
                }
                
                // Filmstrip
                Filmstrip(appState: appState)
            }
            .background(Color.black)
            .task(id: appState.selectedAssetId) {
                // Load preview only (critical path)
                await loadPreview()
                
                // Clear original when switching photos - will reload on-demand
                originalImage = nil
                
                // Prefetch adjacent photos for faster navigation
                appState.prefetchAdjacent()
            }
            .onChange(of: appState.comparisonMode) { _, newMode in
                // Load original only when comparison mode is activated
                if newMode != .none && originalImage == nil {
                    Task {
                        await loadOriginal()
                    }
                }
            }
            .onChange(of: appState.recipes) { oldRecipes, newRecipes in
                // Only update if the selected asset's recipe actually changed
                guard let id = appState.selectedAssetId else { return }

                let oldRecipe = oldRecipes[id]
                let newRecipe = newRecipes[id]

                // Skip if recipes are equal (prevents unnecessary re-renders)
                if oldRecipe == newRecipe {
                    return
                }

                previewTask?.cancel()
                // Show processing indicator when starting a new render
                isProcessingPreview = true
                previewTask = Task {
                    // Keep drag rendering responsive while reducing render thrash.
                    let delay: UInt64 = isSliderDragging ? 24_000_000 : 70_000_000
                    try? await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled else {
                        isProcessingPreview = false
                        return
                    }
                    await loadPreview()
                    isProcessingPreview = false
                }
            }
            .onChange(of: appState.currentLocalNodes) { _, _ in
                // Re-render when local adjustments (masks/nodes) change
                previewTask?.cancel()
                isProcessingPreview = true
                previewTask = Task {
                    try? await Task.sleep(nanoseconds: 70_000_000)
                    guard !Task.isCancelled else {
                        isProcessingPreview = false
                        return
                    }
                    await loadPreview()
                    isProcessingPreview = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .sliderDragStateChanged)) { notification in
                // Switch preview quality based on slider drag state
                if let isDragging = notification.object as? Bool {
                    isSliderDragging = isDragging
                    let targetQuality: AppState.PreviewQuality = isDragging ? .fast : .full
                    if appState.previewQuality != targetQuality {
                        appState.previewQuality = targetQuality
                    }
                }
            }
            .onChange(of: appState.previewQuality) { _, newQuality in
                // Finalize with full-quality render after slider release.
                guard newQuality == .full else { return }
                previewTask?.cancel()
                previewTask = Task {
                    await loadPreview()
                }
            }
            .onChange(of: appState.transformMode) { _, isActive in
                if isActive {
                    withAnimation(.easeOut(duration: 0.15)) {
                        zoomScale = 1.0
                        zoomOffset = .zero
                        dragOffset = .zero
                        appState.isZoomed = false
                    }
                }

                previewTask?.cancel()
                previewTask = Task {
                    await loadPreview()
                }
            }
            .onChange(of: appState.isZoomed) { _, newValue in
                withAnimation(.spring(response: 0.3)) {
                    if newValue {
                        zoomScale = 2.0
                    } else {
                        zoomScale = 1.0
                        zoomOffset = .zero
                        dragOffset = .zero
                    }
                }
            }
            // Navigation
            .onKeyPress("]") { appState.selectNext(); return .handled }
            .onKeyPress("[") { appState.selectPrevious(); return .handled }
            // Keyboard shortcuts - extracted to reduce type-check complexity
            .modifier(SingleViewKeyboardShortcuts(
                appState: appState,
                showOriginal: $showOriginal,
                zoomScale: $zoomScale,
                zoomOffset: $zoomOffset,
                dragOffset: $dragOffset,
                setRating: setRating,
                setFlag: setFlag,
                setColor: setColor
            ))
            // AI Editor sheet
            .sheet(isPresented: $showAIEditor) {
                if let asset = appState.selectedAsset {
                    NanoBananaEditorView(appState: appState, asset: asset)
                }
            }
            // Hidden button for AI Editor keyboard shortcut (⌘⇧A)
            .background {
                Button("") {
                    if appState.selectedAsset != nil {
                        showAIEditor = true
                    }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .opacity(0)
            }
        }
        // UI test hook
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("singleView")
    }
    
    // MARK: - Keyboard Shortcuts Modifier
    
    private struct SingleViewKeyboardShortcuts: ViewModifier {
        let appState: AppState
        @Binding var showOriginal: Bool
        @Binding var zoomScale: CGFloat
        @Binding var zoomOffset: CGSize
        @Binding var dragOffset: CGSize
        let setRating: (Int) -> Void
        let setFlag: (Flag) -> Void
        let setColor: (ColorLabel) -> Void
        
        func body(content: Content) -> some View {
            content
                // Zoom toggle
                .onKeyPress("z") {
                    appState.isZoomed.toggle()
                    return .handled
                }
                // Comparison toggle
                .onKeyPress("\\") {
                    withAnimation {
                        appState.comparisonMode = appState.comparisonMode == .sideBySide ? .none : .sideBySide
                    }
                    return .handled
                }
                // Transform mode toggle (C)
                .onKeyPress("c") {
                    // Save history before entering transform mode for undo support
                    if !appState.transformMode {
                        if let id = appState.selectedAssetId,
                           let recipe = appState.recipes[id] {
                            appState.pushHistory(recipe)
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.transformMode.toggle()
                    }
                    return .handled
                }
                // Enter to commit transform mode
                .onKeyPress(.return) {
                    if appState.transformMode {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.transformMode = false
                        }
                        return .handled
                    }
                    return .ignored
                }
                // Escape to reset
                .onKeyPress(.escape) {
                    // Exit mask painting mode first if active
                    if appState.maskPaintingMode {
                        appState.maskPaintingMode = false
                        return .handled
                    }

                    // Exit transform mode
                    if appState.transformMode {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.transformMode = false
                        }
                        return .handled
                    }

                    showOriginal = false
                    appState.comparisonMode = .none
                    withAnimation {
                        zoomScale = 1.0
                        zoomOffset = .zero
                        dragOffset = .zero
                    }
                    return .handled
                }
                // Rating shortcuts: 0-5
                .onKeyPress("0") { setRating(0); return .handled }
                .onKeyPress("1") { setRating(1); return .handled }
                .onKeyPress("2") { setRating(2); return .handled }
                .onKeyPress("3") { setRating(3); return .handled }
                .onKeyPress("4") { setRating(4); return .handled }
                .onKeyPress("5") { setRating(5); return .handled }
                // Flag shortcuts: P=Pick, X=Reject, U=Unflag
                .onKeyPress("p") { setFlag(.pick); return .handled }
                .onKeyPress("x") { setFlag(.reject); return .handled }
                .onKeyPress("u") { setFlag(.none); return .handled }
                // Color shortcuts: 6=Red, 7=Yellow, 8=Green, 9=Blue
                .onKeyPress("6") { setColor(.red); return .handled }
                .onKeyPress("7") { setColor(.yellow); return .handled }
                .onKeyPress("8") { setColor(.green); return .handled }
                .onKeyPress("9") { setColor(.blue); return .handled }
                // Undo/Redo via standard macOS menu commands
                .onCommand(#selector(UndoManager.undo)) {
                    appState.undo()
                }
                .onCommand(#selector(UndoManager.redo)) {
                    appState.redo()
                }
        }
    }
    
    // MARK: - AI Edit Button

    /// Toolbar with Transform (Crop) and AI Edit buttons
    private struct TransformToolbar: View {
        @Binding var transformMode: Bool
        @Binding var showAIEditor: Bool
        let hasAsset: Bool
        let onEnterTransformMode: () -> Void

        var body: some View {
            if hasAsset {
                HStack(spacing: 8) {
                    // Crop/Transform button
                    Button {
                        // Save history before entering transform mode for undo support
                        if !transformMode {
                            onEnterTransformMode()
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            transformMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crop")
                                .font(.system(size: 10))
                                .foregroundColor(transformMode ? .accentColor : .white)
                            Text("Crop")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(transformMode ? Color.accentColor.opacity(0.3) : .black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .help("Enter Transform Mode (C)")

                    // AI Edit button
                    Button {
                        showAIEditor = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text("AI Edit")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .help("Open AI Editor (⌘⇧A)")
                }
                .padding(16)
            }
        }
    }
    
    // MARK: - Keyboard Actions
    
    private func setColor(_ color: ColorLabel) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.colorLabel = recipe.colorLabel == color ? .none : color
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        appState.showHUD("Color Label: \(color.rawValue.capitalized)")
    }
    
    private func setRating(_ rating: Int) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.rating = rating
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        appState.showHUD("Rating: \(rating) Stars")
    }
    
    private func setFlag(_ flag: Flag) {
        guard let id = appState.selectedAssetId else { return }
        var recipe = appState.recipes[id] ?? EditRecipe()
        recipe.flag = recipe.flag == flag ? .none : flag
        appState.recipes[id] = recipe
        appState.saveCurrentRecipe()
        appState.showHUD("Flag: \(flag.displayName)")
    }
    
    // MARK: - Subviews
    
    private struct MainImageView: View {
        let displayImage: NSImage?
        let isLoadingPreview: Bool
        let isProcessingPreview: Bool
        let showOriginal: Bool
        @Binding var zoomScale: CGFloat
        @Binding var zoomOffset: CGSize
        @Binding var dragOffset: CGSize
        let currentCrop: Binding<Crop>
        let gridOverlay: GridOverlay
        let appState: AppState
        let geometry: GeometryProxy
        let toggleZoom: () -> Void

        @State private var imageViewSize: CGSize = .zero
        @State private var magnifyGestureScale: CGFloat = 1.0
        @State private var lastMagnifyScale: CGFloat = 1.0

        // Zoom constants
        private let minZoomScale: CGFloat = 0.25
        private let maxZoomScale: CGFloat = 8.0

        /// Calculate actual pixel scale (fittedScale * userScale)
        private func calculateFittedScale(imageSize: CGSize, viewSize: CGSize) -> CGFloat {
            let widthRatio = viewSize.width / imageSize.width
            let heightRatio = viewSize.height / imageSize.height
            return min(widthRatio, heightRatio)
        }

        /// Zoom percentage display
        private var zoomPercentageText: String {
            let percentage = Int(zoomScale * 100)
            return "\(percentage)%"
        }

        /// Clamp offset to keep image within view bounds when zoomed
        private func clampOffset(_ offset: CGSize, imageSize: CGSize, viewSize: CGSize) -> CGSize {
            guard zoomScale > 1.0 else { return .zero }

            // Calculate the scaled image dimensions
            let fittedScale = calculateFittedScale(imageSize: imageSize, viewSize: viewSize)
            let scaledWidth = imageSize.width * fittedScale * zoomScale
            let scaledHeight = imageSize.height * fittedScale * zoomScale

            // Calculate max allowed offset (half of overflow in each direction)
            let maxOffsetX = max(0, (scaledWidth - viewSize.width) / 2)
            let maxOffsetY = max(0, (scaledHeight - viewSize.height) / 2)

            return CGSize(
                width: min(max(offset.width, -maxOffsetX), maxOffsetX),
                height: min(max(offset.height, -maxOffsetY), maxOffsetY)
            )
        }

        /// Handle scroll wheel zoom with anchor point at cursor
        private func handleScrollWheelZoom(event: NSEvent, imageSize: CGSize, viewSize: CGSize) {
            let delta = event.scrollingDeltaY
            guard abs(delta) > 0.1 else { return }

            // Calculate zoom factor (smaller delta = finer control)
            let zoomFactor: CGFloat = 1.0 + (delta * 0.01)
            let newScale = min(max(zoomScale * zoomFactor, minZoomScale), maxZoomScale)

            // Get cursor position relative to view center
            let cursorInWindow = event.locationInWindow
            // Convert to view coordinates (origin at center)
            let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)

            // Calculate the point we want to keep fixed (in image space)
            let pointInView = CGPoint(
                x: cursorInWindow.x - viewCenter.x - zoomOffset.width,
                y: -(cursorInWindow.y - viewCenter.y) - zoomOffset.height  // Flip Y
            )

            // Calculate new offset to keep anchor point fixed
            let scaleRatio = newScale / zoomScale
            let newOffset = CGSize(
                width: zoomOffset.width - pointInView.x * (scaleRatio - 1),
                height: zoomOffset.height + pointInView.y * (scaleRatio - 1)
            )

            // Apply zoom
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                zoomScale = newScale
                if newScale > 1.0 {
                    zoomOffset = clampOffset(newOffset, imageSize: imageSize, viewSize: viewSize)
                    dragOffset = zoomOffset
                    appState.isZoomed = true
                } else {
                    zoomOffset = .zero
                    dragOffset = .zero
                    appState.isZoomed = false
                }
            }
            lastMagnifyScale = newScale
        }

        var body: some View {
            ZStack {
                Color.black
                
                if let image = displayImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(zoomScale)
                        .offset(zoomOffset)
                        .padding(20 * zoomScale)
                        .shadow(color: .black.opacity(0.5), radius: 20)
                        .background(
                            GeometryReader { imageGeometry in
                                Color.clear
                                    .onAppear {
                                        imageViewSize = imageGeometry.size
                                    }
                                    .onChange(of: imageGeometry.size) { _, newSize in
                                        imageViewSize = newSize
                                    }
                            }
                        )
                        .gesture(
                            // Pan gesture when zoomed
                            DragGesture()
                                .onChanged { value in
                                    if zoomScale > 1.0 {
                                        let newOffset = CGSize(
                                            width: dragOffset.width + value.translation.width,
                                            height: dragOffset.height + value.translation.height
                                        )
                                        // Clamp pan to image bounds
                                        zoomOffset = clampOffset(newOffset, imageSize: image.size, viewSize: geometry.size)
                                    }
                                }
                                .onEnded { value in
                                    if zoomScale > 1.0 {
                                        dragOffset = zoomOffset
                                    }
                                }
                        )
                        .gesture(
                            // Pinch/magnify gesture for trackpad zoom
                            MagnifyGesture()
                                .onChanged { value in
                                    let newScale = lastMagnifyScale * value.magnification
                                    zoomScale = min(max(newScale, minZoomScale), maxZoomScale)
                                }
                                .onEnded { value in
                                    lastMagnifyScale = zoomScale
                                    if zoomScale <= 1.0 {
                                        // Reset offset when zoomed out to fit
                                        withAnimation(.spring(response: 0.3)) {
                                            zoomOffset = .zero
                                            dragOffset = .zero
                                        }
                                        appState.isZoomed = false
                                    } else {
                                        appState.isZoomed = true
                                        // Clamp offset after zoom
                                        let clamped = clampOffset(zoomOffset, imageSize: image.size, viewSize: geometry.size)
                                        if clamped != zoomOffset {
                                            withAnimation(.spring(response: 0.2)) {
                                                zoomOffset = clamped
                                                dragOffset = clamped
                                            }
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            toggleZoom()
                        }
                        .onScrollWheel { event in
                            // Scroll wheel zoom at cursor position
                            handleScrollWheelZoom(event: event, imageSize: image.size, viewSize: geometry.size)
                        }
                        .overlay {
                            // Crop overlay when in transform mode
                            if !showOriginal && appState.transformMode {
                                CropOverlayView(
                                    crop: currentCrop,
                                    imageSize: image.size,
                                    gridOverlay: gridOverlay
                                )
                                .padding(20 * zoomScale)
                            }
                            
                            // Clipping warnings
                            if (appState.showHighlightClipping || appState.showShadowClipping) && !showOriginal {
                                ClippingOverlayView(
                                    image: image,
                                    showHighlights: appState.showHighlightClipping,
                                    showShadows: appState.showShadowClipping
                                )
                                .scaleEffect(zoomScale)
                                .offset(zoomOffset)
                                .padding(20 * zoomScale)
                                .allowsHitTesting(false)
                            }
                        }
                } else if isLoadingPreview {
                    ProgressView("Loading…")
                        .foregroundColor(.secondary)
                } else {
                    EmptyStateView.noPhotoSelected
                }
                
                // Before/After indicator
                if showOriginal {
                    VStack {
                        HStack {
                            Text("BEFORE")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(30)
                            Spacer()
                        }
                        Spacer()
                    }
                }
                
                // Zoom controls
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            // Fit to view
                            ZoomButton(
                                label: "Fit",
                                isActive: zoomScale == 1.0,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 1.0
                                        zoomOffset = .zero
                                        dragOffset = .zero
                                        lastMagnifyScale = 1.0
                                        appState.isZoomed = false
                                    }
                                }
                            )

                            // 50% zoom
                            ZoomButton(
                                label: "50%",
                                isActive: abs(zoomScale - 0.5) < 0.05,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 0.5
                                        zoomOffset = .zero
                                        dragOffset = .zero
                                        lastMagnifyScale = 0.5
                                        appState.isZoomed = false
                                    }
                                }
                            )

                            // 100% (1:1 pixel mapping - 2x scale when fit is ~50%)
                            ZoomButton(
                                label: "100%",
                                isActive: abs(zoomScale - 2.0) < 0.1,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 2.0
                                        lastMagnifyScale = 2.0
                                        appState.isZoomed = true
                                    }
                                }
                            )

                            // 200% zoom
                            ZoomButton(
                                label: "200%",
                                isActive: abs(zoomScale - 4.0) < 0.1,
                                action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 4.0
                                        lastMagnifyScale = 4.0
                                        appState.isZoomed = true
                                    }
                                }
                            )

                            // Current zoom percentage indicator
                            Text(zoomPercentageText)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(minWidth: 40)
                                .padding(.horizontal, 4)
                        }
                        .padding(8)
                        .background(.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(16)
                    }
                }

                // Processing indicator - shows when rendering preview with existing image
                if isProcessingPreview && displayImage != nil {
                    VStack {
                        ProcessingIndicatorBar()
                        Spacer()
                    }
                }
            }
        }
    }

    /// Zoom level button component
    private struct ZoomButton: View {
        let label: String
        let isActive: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .background(isActive ? Color.accentColor : Color.black.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(4)
        }
    }

    /// Subtle processing indicator bar at the top of the preview
    private struct ProcessingIndicatorBar: View {
        @State private var animationOffset: CGFloat = -1.0

        var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.white.opacity(0.1))

                    // Animated gradient bar
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0),
                                    Color.accentColor.opacity(0.8),
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.8),
                                    Color.accentColor.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.3)
                        .offset(x: animationOffset * geometry.size.width)
                }
            }
            .frame(height: 3)
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    animationOffset = 1.0
                }
            }
        }
    }
    
    @ViewBuilder
    private func comparisonImageView(image: NSImage?, label: String) -> some View {
        ZStack {
            Color.black
            
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(10)
            } else {
                ProgressView()
            }
            
            VStack {
                HStack {
                    Text(label)
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                        .padding(12)
                    Spacer()
                }
                Spacer()
            }
        }
        .clipped()
    }
    
    private func toggleZoom() {
        withAnimation(.spring(response: 0.3)) {
            if zoomScale > 1.0 {
                zoomScale = 1.0
                zoomOffset = .zero
                dragOffset = .zero
                appState.isZoomed = false
            } else {
                zoomScale = 2.0
                appState.isZoomed = true
            }
        }
    }
    
    @State private var previewTask: Task<Void, Never>?
    
    private func loadPreview() async {
        guard let asset = appState.selectedAsset else {
            previewImage = nil
            return
        }
        
        isLoadingPreview = true
        
        // Get recipe for this specific asset
        let recipe = appState.recipes[asset.id] ?? EditRecipe()
        var previewRecipe = recipe

        // While editing crop, preview the full transformed frame so overlay and output stay aligned.
        if appState.transformMode {
            previewRecipe.crop.isEnabled = false
        }
        
        // ===== P1: TWO-STAGE LOADING =====
        
        // Stage 1: Show instant embedded preview ONLY if we don't have a preview yet
        // This prevents flickering back to original when adjusting values
        let isInitialLoad = previewImage == nil
        
        if isInitialLoad {
            // First time loading - show quick preview immediately
            if let quickPreview = await ImagePipeline.shared.quickPreview(for: asset) {
                previewImage = quickPreview
                appState.currentPreviewImage = quickPreview
                isLoadingPreview = false  // Hide loading immediately
            }
        }
        
        // Stage 2: Load full edited version
        // Always do this when there are edits (to apply them)
        let hasEdits = previewRecipe.hasEdits
        let needsFullRender = hasEdits || isInitialLoad || appState.previewQuality == .full

        if needsFullRender {
            // Use quality-aware resolution
            let isFastMode = appState.previewQuality == .fast || isSliderDragging
            // While scrubbing sliders, prefer lower-resolution preview to keep interactions responsive.
            let maxSize: CGFloat = isFastMode
                ? min(appState.previewQuality.maxSize, 720)
                : appState.previewQuality.maxSize
            let sliderSignpostId = PerformanceSignposts.signposter.makeSignpostID()
            let sliderSignpostState = isSliderDragging
                ? PerformanceSignposts.begin("sliderDragRender", id: sliderSignpostId)
                : nil
            defer { PerformanceSignposts.end("sliderDragRender", sliderSignpostState) }
            
            // Use ImagePipeline for preview with recipe applied
            let fullPreview = await ImagePipeline.shared.renderPreview(
                for: asset,
                recipe: previewRecipe,
                maxSize: maxSize,
                fastMode: isFastMode,
                localNodes: appState.currentLocalNodes
            )
            
            // Only update if we got a result
            if let full = fullPreview {
                previewImage = full
                // Keep histogram updates off the hot path during slider drags.
                if !isSliderDragging || appState.currentPreviewImage == nil {
                    appState.currentPreviewImage = full
                }
            }
        }
        
        isLoadingPreview = false
    }
    
    private func loadOriginal() async {
        guard let asset = appState.selectedAsset else {
            originalImage = nil
            return
        }
        
        // Load original without any recipe applied
        originalImage = await ImagePipeline.shared.renderPreview(
            for: asset,
            recipe: EditRecipe(), // Empty recipe = original
            maxSize: 1600
        )
    }
    
    // MARK: - Eyedropper Logic
    
    /// Sample color at point and update white balance
    private func pickWhitePoint(at point: CGPoint, in size: CGSize) {
        guard let image = previewImage, let id = appState.selectedAssetId else { return }
        
        // 1. Map container point to image coordinates
        // This is a simplified version - assumes "fit" mode with no zoom/offset for now
        // To be robust, it should account for zoomScale and zoomOffset
        
        let imgSize = image.size
        let viewAspect = size.width / size.height
        let imgAspect = imgSize.width / imgSize.height
        
        var drawRect = CGRect.zero
        if imgAspect > viewAspect {
            let h = size.width / imgAspect
            drawRect = CGRect(x: 0, y: (size.height - h) / 2, width: size.width, height: h)
        } else {
            let w = size.height * imgAspect
            drawRect = CGRect(x: (size.width - w) / 2, y: 0, width: w, height: size.height)
        }
        
        // Check if click is inside image
        guard drawRect.contains(point) else { return }
        
        // Normalize coordinates to [0, 1] relative to image
        let normX = (point.x - drawRect.minX) / drawRect.width
        let normY = 1.0 - (point.y - drawRect.minY) / drawRect.height // NSImage/CoreGraphics coordinate flip
        
        // 2. Sample pixel color
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let pixelX = Int(normX * CGFloat(cgImage.width))
        let pixelY = Int(normY * CGFloat(cgImage.height))
        
        if let color = getPixelColor(in: cgImage, x: pixelX, y: pixelY) {
            // 3. Calculate WB shift
            // Basic heuristic: find neutral shift to make sampled point gray
            // We use simple corrections for temperature (blue/yellow) and tint (green/magenta)
            
            let luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
            if luminance < 0.05 || luminance > 0.95 { return } // Avoid extreme points
            
            // Adjust current recipe
            var recipe = appState.recipes[id] ?? EditRecipe()
            
            // Temperature adjustment (Blue/Yellow balance)
            let bToR = color.b / color.r
            let tempShift = Int((bToR - 1.0) * 2000)
            recipe.whiteBalance.temperature = max(2000, min(12000, recipe.whiteBalance.temperature + tempShift))
            
            // Tint adjustment (Green/Magenta balance)
            let gToAvg = color.g / ((color.r + color.b) / 2.0)
            let tintShift = Int((gToAvg - 1.0) * 100)
            recipe.whiteBalance.tint = max(-150, min(150, recipe.whiteBalance.tint - tintShift))
            
            recipe.whiteBalance.preset = .custom
            
            appState.recipes[id] = recipe
            appState.saveCurrentRecipe()
            
            // Turn off eyedropper
            appState.eyedropperMode = false
        }
    }
    
    private func getPixelColor(in image: CGImage, x: Int, y: Int) -> (r: Double, g: Double, b: Double)? {
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }
        
        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel
        
        // Assuming RGBA8888 or BGRA8888
        let r = Double(ptr[offset]) / 255.0
        let g = Double(ptr[offset + 1]) / 255.0
        let b = Double(ptr[offset + 2]) / 255.0
        return (r, g, b)
    }
}

/// Bottom info bar showing metadata
struct InfoBar: View {
    let asset: PhotoAsset
    let metadata: ImageMetadata?
    
    var body: some View {
        HStack(spacing: 12) {
            // Filename
            Text(asset.filename)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("•")
                .foregroundColor(.secondary)
            
            // Metadata (placeholder for now)
            if let metadata = metadata {
                Text(metadata.exposureDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("ISO 100  f/2.8  1/200s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Format badge
            Text(asset.fileExtension)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(asset.isRAW ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.2))
                .foregroundColor(asset.isRAW ? .orange : .secondary)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.15, alpha: 1.0)))
    }
}

/// Bottom filmstrip for navigation
struct Filmstrip: View {
    @ObservedObject var appState: AppState
    
    // Responsive breakpoint
    private let narrowThreshold: CGFloat = 600
    
    var body: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < narrowThreshold
            let thumbnailSize: CGFloat = isNarrow ? 60 : 80
            let height: CGFloat = isNarrow ? 70 : 90
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isNarrow ? 6 : 8) {
                        // Use filteredAssets to match GridView order
                        ForEach(appState.filteredAssets) { asset in
                            FilmstripThumbnail(
                                asset: asset,
                                isSelected: appState.selectedAssetId == asset.id,
                                size: thumbnailSize
                            )
                            .id(asset.id)
                            .onTapGesture {
                                appState.selectedAssetId = asset.id
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: NSColor(calibratedWhite: 0.1, alpha: 1.0)))
                .onChange(of: appState.selectedAssetId) { _, newId in
                    if let id = newId {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
                .overlay {
                    // HUD Notification
                    if let message = appState.hudMessage {
                        Text(message)
                            .font(isNarrow ? .subheadline : .headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                }
            }
            .frame(height: height)
        }
        .frame(height: 90) // Max height, will shrink for narrow windows via content
    }
}

/// Single thumbnail in the filmstrip
struct FilmstripThumbnail: View {
    let asset: PhotoAsset
    let isSelected: Bool
    var size: CGFloat = 80  // Default thumbnail size
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                // Loading placeholder with shimmer effect
                ShimmerLoadingView()
                    .frame(width: size, height: size)
            }
            
            // RAW badge
            if asset.isRAW {
                VStack {
                    HStack {
                        Spacer()
                        Text("RAW")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.7))
                            .foregroundColor(.orange)
                            .cornerRadius(3)
                    }
                    Spacer()
                }
                .padding(4)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : .clear, radius: 4)
        .opacity(isSelected ? 1.0 : 0.6)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset)
        }
    }
}

/// Overlay view that highlights clipped pixels (red for highlights, blue for shadows)
struct ClippingOverlayView: View {
    let image: NSImage
    let showHighlights: Bool
    let showShadows: Bool
    
    @State private var clippingMask: NSImage?
    
    var body: some View {
        ZStack {
            if let mask = clippingMask {
                Image(nsImage: mask)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .task(id: image) {
            generateMask()
        }
        .onChange(of: showHighlights) { _, _ in generateMask() }
        .onChange(of: showShadows) { _, _ in generateMask() }
    }
    
    private func generateMask() {
        // We generate a low-res mask for performance
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }
        
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        
        // Target a small mask size for fast generation and rendering
        let targetWidth = 400
        let targetHeight = Int(CGFloat(height) / CGFloat(width) * CGFloat(targetWidth))
        
        let maskRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetWidth,
            pixelsHigh: targetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        let stepX = Double(width) / Double(targetWidth)
        let stepY = Double(height) / Double(targetHeight)
        
        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let srcX = Int(Double(x) * stepX)
                let srcY = Int(Double(y) * stepY)
                
                guard let color = bitmap.colorAt(x: srcX, y: srcY) else { continue }
                
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                
                var maskColor = NSColor.clear
                
                if showHighlights && (r > 0.99 || g > 0.99 || b > 0.99) {
                    maskColor = NSColor.red.withAlphaComponent(0.8)
                } else if showShadows && (r < 0.01 && g < 0.01 && b < 0.01) {
                    maskColor = NSColor.blue.withAlphaComponent(0.8)
                }
                
                maskRep.setColor(maskColor, atX: x, y: y)
            }
        }
        
        let maskImage = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        maskImage.addRepresentation(maskRep)
        
        DispatchQueue.main.async {
            self.clippingMask = maskImage
        }
    }
}

// MARK: - AI Generation Progress Overlay

/// Overlay showing AI generation progress
private struct AIGenerationProgressOverlay: View {
    let state: AIGenerationState

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // Progress card
            VStack(spacing: 16) {
                // Icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .symbolEffect(.pulse, options: .repeating)

                // Title
                Text("AI Generation")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                // Status text
                Text(state.statusText)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))

                // Progress indicator
                progressIndicator
                    .frame(width: 180)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.15))
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: state)
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch state {
        case .uploading(let progress):
            VStack(spacing: 4) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

        case .processing(let progress):
            VStack(spacing: 4) {
                ProgressView(value: Double(progress), total: 100)
                    .progressViewStyle(.linear)
                    .tint(.green)
                Text("\(progress)%")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

        case .idle, .complete, .failed:
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)
                .tint(.white)
        }
    }
}

// MARK: - Scroll Wheel Modifier

/// View extension for handling scroll wheel events (macOS)
extension View {
    func onScrollWheel(action: @escaping (NSEvent) -> Void) -> some View {
        self.background(
            ScrollWheelHandler(action: action)
        )
    }
}

/// NSViewRepresentable to capture scroll wheel events
private struct ScrollWheelHandler: NSViewRepresentable {
    let action: (NSEvent) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.action = action
    }
}

/// Custom NSView that captures scroll wheel events
private class ScrollWheelNSView: NSView {
    var action: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        // Only handle trackpad/mouse wheel scroll (ignore momentum events).
        if event.momentumPhase == [] {
            action?(event)
        }
    }

    override var acceptsFirstResponder: Bool { true }
}

#Preview {
    SingleView(appState: AppState())
        .preferredColorScheme(.dark)
}
