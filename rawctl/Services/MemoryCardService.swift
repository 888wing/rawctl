//
//  MemoryCardService.swift
//  rawctl
//
//  Memory card detection and auto-export
//

import Foundation
import AppKit

/// Service for detecting memory cards and auto-exporting
/// Note: This is a MainActor class since it primarily interacts with UI state
@MainActor
final class MemoryCardService {
    static let shared = MemoryCardService()
    
    private var volumeObserver: NSObjectProtocol?
    private var isMonitoring = false
    
    /// Known camera card volume names and identifiers
    private let cameraCardIndicators = [
        "DCIM",           // Standard DCIM folder on camera cards
        "EOS_DIGITAL",    // Canon
        "NIKON",          // Nikon
        "SONY",           // Sony
        "PRIVATE",        // Generic camera folder
    ]
    
    /// Start monitoring for volume changes
    func startMonitoring(appState: AppState) {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Initial scan of mounted volumes
        scanForCameraCards(appState: appState)
        
        // Watch for new volumes
        volumeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak appState] notification in
            guard let self = self,
                  let appState = appState,
                  let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else {
                return
            }
            
            Task { @MainActor in
                if self.isCameraCard(volumeURL) {
                    appState.monitoredVolumes.append(volumeURL)
                    
                    // Auto-import if enabled
                    if appState.autoExportEnabled, let destination = appState.autoExportDestination {
                        await self.autoImportAndExport(from: volumeURL, to: destination, appState: appState)
                    }
                }
            }
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        if let observer = volumeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            volumeObserver = nil
        }
        isMonitoring = false
    }
    
    /// Scan currently mounted volumes for camera cards
    private func scanForCameraCards(appState: AppState) {
        let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
        
        for volumeURL in volumeURLs {
            if isCameraCard(volumeURL) {
                if !appState.monitoredVolumes.contains(volumeURL) {
                    appState.monitoredVolumes.append(volumeURL)
                }
            }
        }
    }
    
    /// Check if a volume is likely a camera card
    nonisolated private func isCameraCard(_ volumeURL: URL) -> Bool {
        // Check if it's removable
        let values = try? volumeURL.resourceValues(forKeys: [.volumeIsRemovableKey])
        let isRemovable = values?.volumeIsRemovable ?? false
        
        if !isRemovable { return false }
        
        // Check for DCIM folder (standard camera structure)
        let dcimURL = volumeURL.appendingPathComponent("DCIM")
        if FileManager.default.fileExists(atPath: dcimURL.path) {
            return true
        }
        
        // Check for known camera indicators
        let volumeName = volumeURL.lastPathComponent.uppercased()
        for indicator in cameraCardIndicators {
            if volumeName.contains(indicator) {
                return true
            }
        }
        
        return false
    }
    
    /// Find the DCIM folder on a camera card
    nonisolated private func findDCIMFolder(on volumeURL: URL) -> URL? {
        let dcimURL = volumeURL.appendingPathComponent("DCIM")
        if FileManager.default.fileExists(atPath: dcimURL.path) {
            return dcimURL
        }
        return nil
    }
    
    /// Auto import and export from camera card
    func autoImportAndExport(from cardURL: URL, to destination: URL, appState: AppState) async {
        guard let dcimURL = findDCIMFolder(on: cardURL) else { return }
        
        appState.isLoading = true
        appState.loadingMessage = "Scanning memory card..."
        
        do {
            // Scan for images
            let assets = try await FileSystemService.scanFolder(dcimURL)
            
            appState.assets = assets
            appState.selectedFolder = dcimURL
            appState.loadingMessage = "Exporting \(assets.count) photos..."
            
            // Export all photos
            var recipes: [UUID: EditRecipe] = [:]
            for asset in assets {
                // Try to load existing sidecar
                if let (recipe, _) = await SidecarService.shared.loadRecipeAndSnapshots(for: asset.url) {
                    recipes[asset.id] = recipe
                } else {
                    recipes[asset.id] = EditRecipe()
                }
            }
            
            let settings = ExportSettings(
                destinationFolder: destination,
                quality: 85,
                sizeOption: .original,
                filenameSuffix: "",
                exportSelection: .all
            )
            
            await ExportService.shared.startExport(
                assets: assets,
                recipes: recipes,
                settings: settings
            )
            
            appState.isLoading = false
            appState.loadingMessage = ""
            
        } catch {
            appState.isLoading = false
        }
    }
    
    /// Get list of detected camera cards
    func getDetectedCards() -> [URL] {
        let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsRemovableKey],
            options: [.skipHiddenVolumes]
        ) ?? []
        
        return volumeURLs.filter { isCameraCard($0) }
    }
    
    /// Open a camera card folder directly
    func openCameraCard(_ url: URL, appState: AppState) async {
        print("[MemoryCard] Opening camera card: \(url.path)")
        
        // Try to find DCIM folder, or use the URL directly if it's already a folder with images
        var scanURL = url
        if let dcimURL = findDCIMFolder(on: url) {
            scanURL = dcimURL
            print("[MemoryCard] Found DCIM folder: \(dcimURL.path)")
        } else {
            print("[MemoryCard] No DCIM folder found, scanning root: \(url.path)")
        }
        
        appState.selectedFolder = scanURL
        appState.isLoading = true
        appState.loadingMessage = "Scanning memory card..."
        
        do {
            let assets = try await FileSystemService.scanFolder(scanURL)
            print("[MemoryCard] Found \(assets.count) photos")
            
            appState.assets = assets
            appState.recipes = [:]
            appState.isLoading = false
            
            // Load all recipes
            await appState.loadAllRecipes()
            
            if let first = appState.assets.first {
                appState.selectedAssetId = first.id
                print("[MemoryCard] Selected first asset: \(first.filename)")
            } else {
                print("[MemoryCard] No assets found!")
            }
        } catch {
            print("[MemoryCard] Error scanning: \(error)")
            appState.isLoading = false
        }
    }
}
