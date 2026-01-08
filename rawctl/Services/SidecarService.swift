//
//  SidecarService.swift
//  rawctl
//
//  Sidecar JSON read/write with debounced auto-save
//

import Foundation
import Combine

/// Service for reading and writing sidecar JSON files
actor SidecarService {
    static let shared = SidecarService()
    
    private var saveTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    
    /// Read recipe and snapshots from sidecar file
    func loadRecipeAndSnapshots(for assetURL: URL) async -> (EditRecipe, [RecipeSnapshot])? {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: sidecarURL)
            let decoder = JSONDecoder()
            let sidecar = try decoder.decode(SidecarFile.self, from: data)
            return (sidecar.edit, sidecar.snapshots)
        } catch {
            print("Failed to load sidecar: \(error)")
            return nil
        }
    }
    
    /// Read recipe, snapshots, and AI edits from sidecar file
    func loadRecipeAndAIEdits(for assetURL: URL) async -> (EditRecipe, [RecipeSnapshot], [AIEdit])? {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: sidecarURL)
            let decoder = JSONDecoder()
            let sidecar = try decoder.decode(SidecarFile.self, from: data)
            return (sidecar.edit, sidecar.snapshots, sidecar.aiEdits)
        } catch {
            print("Failed to load sidecar: \(error)")
            return nil
        }
    }
    
    /// Save recipe and snapshots to sidecar file (debounced)
    func saveRecipe(_ recipe: EditRecipe, snapshots: [RecipeSnapshot], for assetURL: URL) async {
        // Cancel any pending save
        saveTask?.cancel()
        
        // Create debounced save task
        saveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            await performSave(recipe, snapshots: snapshots, for: assetURL)
        }
    }
    
    private func performSave(_ recipe: EditRecipe, snapshots: [RecipeSnapshot], for assetURL: URL) async {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        
        var sidecar = SidecarFile(for: assetURL, recipe: recipe)
        sidecar.snapshots = snapshots
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sidecar)
            try data.write(to: sidecarURL, options: .atomic)
        } catch {
            print("Failed to save sidecar: \(error)")
        }
    }
    
    /// Delete sidecar file
    func deleteSidecar(for assetURL: URL) async {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        try? FileManager.default.removeItem(at: sidecarURL)
    }
    
    /// Check if asset has sidecar
    func hasSidecar(for assetURL: URL) -> Bool {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        return FileManager.default.fileExists(atPath: sidecarURL.path)
    }
    
    // MARK: - AI Edits
    
    /// Save AI edits to sidecar file
    func saveAIEdits(_ aiEdits: [AIEdit], for assetURL: URL) async {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        
        // Load existing sidecar or create new one
        var sidecar: SidecarFile
        if FileManager.default.fileExists(atPath: sidecarURL.path),
           let data = try? Data(contentsOf: sidecarURL),
           let existing = try? JSONDecoder().decode(SidecarFile.self, from: data) {
            sidecar = existing
        } else {
            sidecar = SidecarFile(for: assetURL, recipe: EditRecipe())
        }
        
        // Update AI edits
        sidecar.aiEdits = aiEdits
        sidecar.updatedAt = Date().timeIntervalSince1970
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sidecar)
            try data.write(to: sidecarURL, options: .atomic)
        } catch {
            print("[SidecarService] Failed to save AI edits: \(error)")
        }
    }
    
    /// Load only AI edits from sidecar
    func loadAIEdits(for assetURL: URL) async -> [AIEdit] {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        
        guard FileManager.default.fileExists(atPath: sidecarURL.path),
              let data = try? Data(contentsOf: sidecarURL),
              let sidecar = try? JSONDecoder().decode(SidecarFile.self, from: data) else {
            return []
        }
        
        return sidecar.aiEdits
    }
    
    /// Add a single AI edit
    func addAIEdit(_ edit: AIEdit, for assetURL: URL) async {
        var edits = await loadAIEdits(for: assetURL)
        edits.append(edit)
        await saveAIEdits(edits, for: assetURL)
    }
    
    /// Remove an AI edit
    func removeAIEdit(_ editId: UUID, for assetURL: URL) async {
        var edits = await loadAIEdits(for: assetURL)
        edits.removeAll { $0.id == editId }
        await saveAIEdits(edits, for: assetURL)
    }
    
    /// Toggle AI edit visibility
    func toggleAIEdit(_ editId: UUID, for assetURL: URL) async {
        var edits = await loadAIEdits(for: assetURL)
        if let index = edits.firstIndex(where: { $0.id == editId }) {
            edits[index].enabled.toggle()
            await saveAIEdits(edits, for: assetURL)
        }
    }
}
