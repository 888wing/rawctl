//
//  ImportView.swift
//  rawctl
//
//  Import photos from memory card to local library
//

import SwiftUI

/// Import dialog for copying photos from source to local library
struct ImportView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var sourceURL: URL?
    @State private var destinationURL: URL?
    @State private var photosToImport: [PhotoAsset] = []
    @State private var selectedPhotos: Set<UUID> = []
    @State private var isScanning = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var importedCount = 0
    @State private var createDateFolder = true
    @State private var deleteAfterImport = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import Photos")
                    .font(.title2.bold())
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            HStack(spacing: 0) {
                // Left: Source selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source")
                        .font(.headline)
                    
                    // Source folder button
                    Button {
                        selectSource()
                    } label: {
                        HStack {
                            Image(systemName: "sdcard.fill")
                                .foregroundColor(.orange)
                            Text(sourceURL?.lastPathComponent ?? "Select Memory Card...")
                            Spacer()
                            Image(systemName: "folder")
                        }
                        .padding()
                        .background(Color(white: 0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    if isScanning {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Scanning...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !photosToImport.isEmpty {
                        Text("\(photosToImport.count) photos found")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("Select All") {
                                selectedPhotos = Set(photosToImport.map { $0.id })
                            }
                            .font(.caption)
                            
                            Button("Deselect All") {
                                selectedPhotos = []
                            }
                            .font(.caption)
                        }
                    }
                    
                    Spacer()
                    
                    // Destination folder
                    Text("Destination")
                        .font(.headline)
                    
                    Button {
                        selectDestination()
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.accentColor)
                            Text(destinationURL?.path ?? "Select Local Folder...")
                            Spacer()
                            Image(systemName: "folder")
                        }
                        .padding()
                        .background(Color(white: 0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    // Options
                    Toggle("Create date folders (YYYY-MM-DD)", isOn: $createDateFolder)
                        .font(.caption)
                    
                    Toggle("Delete from card after import", isOn: $deleteAfterImport)
                        .font(.caption)
                        .foregroundColor(deleteAfterImport ? .orange : .primary)
                }
                .padding()
                .frame(width: 280)
                .background(Color(nsColor: .windowBackgroundColor))
                
                Divider()
                
                // Right: Photo preview grid
                VStack {
                    if photosToImport.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Select a source folder to preview photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(photosToImport) { photo in
                                    ImportThumbnail(
                                        asset: photo,
                                        isSelected: selectedPhotos.contains(photo.id),
                                        onTap: {
                                            if selectedPhotos.contains(photo.id) {
                                                selectedPhotos.remove(photo.id)
                                            } else {
                                                selectedPhotos.insert(photo.id)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
                .background(Color(white: 0.1))
            }
            
            Divider()
            
            // Footer with import button
            HStack {
                if isImporting {
                    ProgressView(value: importProgress)
                        .frame(width: 200)
                    Text("\(importedCount)/\(selectedPhotos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("Import \(selectedPhotos.count) Photos") {
                    Task {
                        await performImport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedPhotos.isEmpty || destinationURL == nil || isImporting)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 800, height: 550)
    }
    
    // MARK: - Actions
    
    private func selectSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.message = "Select memory card or folder to import from"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourceURL = url
            Task {
                await scanSource(url)
            }
        }
    }
    
    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select local folder to import photos to"
        
        if panel.runModal() == .OK {
            destinationURL = panel.url
        }
    }
    
    private func scanSource(_ url: URL) async {
        isScanning = true
        photosToImport = []
        selectedPhotos = []
        
        do {
            // Try DCIM folder first
            let dcimURL = url.appendingPathComponent("DCIM")
            let scanURL = FileManager.default.fileExists(atPath: dcimURL.path) ? dcimURL : url
            
            let assets = try await FileSystemService.scanFolder(scanURL)
            await MainActor.run {
                photosToImport = assets
                selectedPhotos = Set(assets.map { $0.id })
                isScanning = false
            }
        } catch {
            await MainActor.run {
                isScanning = false
            }
        }
    }
    
    private func performImport() async {
        guard let destination = destinationURL else { return }
        
        isImporting = true
        importedCount = 0
        importProgress = 0
        
        let photosToProcess = photosToImport.filter { selectedPhotos.contains($0.id) }
        let total = photosToProcess.count
        
        for (index, photo) in photosToProcess.enumerated() {
            // Determine destination folder
            var targetFolder = destination
            
            if createDateFolder {
                // Create date-based subfolder using file modification date
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                // Try to get file creation date
                let fileDate: Date
                if let attrs = try? FileManager.default.attributesOfItem(atPath: photo.url.path),
                   let creationDate = attrs[.creationDate] as? Date {
                    fileDate = creationDate
                } else {
                    fileDate = Date()
                }
                
                let dateString = dateFormatter.string(from: fileDate)
                targetFolder = destination.appendingPathComponent(dateString)
                
                try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
            }
            
            // Copy file
            let destinationFile = targetFolder.appendingPathComponent(photo.filename)
            
            do {
                if !FileManager.default.fileExists(atPath: destinationFile.path) {
                    try FileManager.default.copyItem(at: photo.url, to: destinationFile)
                }
                
                // Copy sidecar if exists
                let sidecarSource = FileSystemService.sidecarURL(for: photo.url)
                if FileManager.default.fileExists(atPath: sidecarSource.path) {
                    let sidecarDest = FileSystemService.sidecarURL(for: destinationFile)
                    try? FileManager.default.copyItem(at: sidecarSource, to: sidecarDest)
                }
                
                // Delete from source if option enabled
                if deleteAfterImport {
                    try? FileManager.default.removeItem(at: photo.url)
                }
                
                await MainActor.run {
                    importedCount = index + 1
                    importProgress = Double(importedCount) / Double(total)
                }
            } catch {
                print("[Import] Error copying \(photo.filename): \(error)")
            }
        }
        
        await MainActor.run {
            isImporting = false
            
            // Open the destination folder
            if let dest = destinationURL {
                Task {
                    await appState.openFolderFromPath(dest.path)
                }
            }
            
            dismiss()
        }
    }
}

/// Thumbnail for import preview
struct ImportThumbnail: View {
    let asset: PhotoAsset
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var thumbnail: NSImage?
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
            }
            
            // Selection checkmark
            VStack {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .white.opacity(0.7))
                        .font(.system(size: 16))
                        .shadow(radius: 2)
                    Spacer()
                }
                Spacer()
            }
            .padding(4)
        }
        .frame(width: 80, height: 80)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .opacity(isSelected ? 1.0 : 0.6)
        .onTapGesture {
            onTap()
        }
        .task {
            thumbnail = await ThumbnailService.shared.thumbnail(for: asset, size: 160)
        }
    }
}

#Preview {
    ImportView(appState: AppState())
        .preferredColorScheme(.dark)
}
