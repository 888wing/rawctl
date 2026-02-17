//
//  SidecarService.swift
//  rawctl
//
//  Sidecar JSON read/write with debounced auto-save
//

import Foundation

/// Service for reading and writing sidecar JSON files
actor SidecarService {
    static let shared = SidecarService()
    
    private struct PendingSave {
        let requestId: UUID
        let assetURL: URL
        let recipe: EditRecipe
        let snapshots: [RecipeSnapshot]
    }

    // Debounce per-asset to avoid cancelling saves across photos.
    private var pendingSaves: [URL: PendingSave] = [:]      // sidecarURL -> save payload
    private var saveTasks: [URL: Task<Void, Never>] = [:]   // sidecarURL -> debounce task
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
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)

        // Cancel any pending save for this asset only.
        saveTasks[sidecarURL]?.cancel()

        let requestId = UUID()
        pendingSaves[sidecarURL] = PendingSave(
            requestId: requestId,
            assetURL: assetURL,
            recipe: recipe,
            snapshots: snapshots
        )

        // Create debounced save task (keyed by sidecar URL).
        saveTasks[sidecarURL] = Task { [debounceInterval] in
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self.performPendingSave(sidecarURL: sidecarURL, requestId: requestId)
        }
    }

    private func performPendingSave(sidecarURL: URL, requestId: UUID) async {
        guard let pending = pendingSaves[sidecarURL],
              pending.requestId == requestId else {
            return
        }

        // Clear pending state before saving to avoid retaining large payloads.
        pendingSaves[sidecarURL] = nil
        saveTasks[sidecarURL] = nil

        await performSave(pending.recipe, snapshots: pending.snapshots, for: pending.assetURL)
    }

    private func performSave(_ recipe: EditRecipe, snapshots: [RecipeSnapshot], for assetURL: URL) async {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)

        // Preserve existing AI edits and other sidecar fields when saving.
        var sidecar: SidecarFile
        if FileManager.default.fileExists(atPath: sidecarURL.path),
           let data = try? Data(contentsOf: sidecarURL),
           let existing = try? JSONDecoder().decode(SidecarFile.self, from: data) {
            sidecar = existing
            sidecar.edit = recipe
            sidecar.snapshots = snapshots
        } else {
            sidecar = SidecarFile(for: assetURL, recipe: recipe)
            sidecar.snapshots = snapshots
        }

        sidecar.updatedAt = Date().timeIntervalSince1970

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sidecar)
            try data.write(to: sidecarURL, options: .atomic)
        } catch {
            print("Failed to save sidecar: \(error)")
        }
    }
    
    /// Save recipe only to sidecar file (preserves existing snapshots and AI edits)
    func saveRecipeOnly(_ recipe: EditRecipe, for assetURL: URL) async {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)

        // Load existing sidecar to preserve snapshots and AI edits
        var sidecar: SidecarFile
        if FileManager.default.fileExists(atPath: sidecarURL.path),
           let data = try? Data(contentsOf: sidecarURL),
           let existing = try? JSONDecoder().decode(SidecarFile.self, from: data) {
            sidecar = existing
            sidecar.edit = recipe
        } else {
            sidecar = SidecarFile(for: assetURL, recipe: recipe)
        }

        sidecar.updatedAt = Date().timeIntervalSince1970

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(sidecar)
            try data.write(to: sidecarURL, options: .atomic)
        } catch {
            print("[SidecarService] Failed to save recipe: \(error)")
        }
    }

    // MARK: - v6: localNodes save/load

    /// Save recipe and optional local adjustment nodes to sidecar file (immediate, throwing).
    /// Uses a default of nil for localNodes so all existing callers compile unchanged.
    func save(recipe: EditRecipe, localNodes: [ColorNode]? = nil, for assetURL: URL) async throws {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)

        var sidecar: SidecarFile
        if FileManager.default.fileExists(atPath: sidecarURL.path) {
            do {
                let data = try Data(contentsOf: sidecarURL)
                var existing = try JSONDecoder().decode(SidecarFile.self, from: data)
                existing.edit = recipe
                sidecar = existing
            } catch {
                print("[SidecarService] Failed to read existing sidecar, creating fresh: \(error)")
                sidecar = SidecarFile(for: assetURL, recipe: recipe)
            }
        } else {
            sidecar = SidecarFile(for: assetURL, recipe: recipe)
        }

        sidecar.localNodes = localNodes
        sidecar.updatedAt = Date().timeIntervalSince1970

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        try data.write(to: sidecarURL, options: .atomic)
    }

    /// Load recipe and local adjustment nodes from sidecar file (throwing).
    func load(for assetURL: URL) async throws -> (recipe: EditRecipe, localNodes: [ColorNode]?) {
        let sidecarURL = FileSystemService.sidecarURL(for: assetURL)
        let data = try Data(contentsOf: sidecarURL)
        let sidecar = try JSONDecoder().decode(SidecarFile.self, from: data)
        return (recipe: sidecar.edit, localNodes: sidecar.localNodes)
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
