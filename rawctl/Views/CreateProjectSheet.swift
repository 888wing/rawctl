//
//  CreateProjectSheet.swift
//  rawctl
//
//  Sheet for creating a new project
//

import SwiftUI

/// Sheet for creating a new project
struct CreateProjectSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var projectName: String = ""
    @State private var clientName: String = ""
    @State private var shootDate: Date = Date()
    @State private var projectType: ProjectType = .portrait
    @State private var sourceFolders: [URL] = []
    @State private var notes: String = ""
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Project")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Form
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Client Name (Optional)", text: $clientName)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("Shoot Date", selection: $shootDate, displayedComponents: .date)

                    Picker("Project Type", selection: $projectType) {
                        ForEach(ProjectType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Source Folders") {
                    VStack(alignment: .leading, spacing: 8) {
                        if sourceFolders.isEmpty {
                            Text("No folders selected")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(sourceFolders, id: \.path) { folder in
                                HStack {
                                    Text(folder.lastPathComponent)
                                        .font(.system(size: 11))
                                        .foregroundColor(.primary)
                                    Text(folder.deletingLastPathComponent().path)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button {
                                        sourceFolders.removeAll { $0 == folder }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Add Folders...") {
                                selectFolders()
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .font(.system(size: 12))
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Create Project") {
                    createProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectName.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 480)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage)
        }
        .onAppear {
            // Auto-generate name from date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            projectName = formatter.string(from: shootDate)
        }
    }

    private func selectFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select folders containing your photos (hold Cmd to select multiple)"

        if panel.runModal() == .OK {
            // Add selected folders (avoiding duplicates)
            for url in panel.urls {
                if !sourceFolders.contains(url) {
                    sourceFolders.append(url)
                }
            }

            // Update project name from first folder if not set
            if projectName.isEmpty || projectName.contains("-") {
                if let firstFolder = panel.urls.first {
                    projectName = firstFolder.lastPathComponent
                }
            }
        }
    }

    private func createProject() {
        var project = Project(
            name: projectName,
            clientName: clientName.isEmpty ? nil : clientName,
            shootDate: shootDate,
            projectType: projectType,
            notes: notes
        )

        if !sourceFolders.isEmpty {
            project.sourceFolders = sourceFolders
        }

        // Add to catalog
        if var catalog = appState.catalog {
            catalog.addProject(project)
            appState.catalog = catalog

            // Save catalog
            Task {
                do {
                    let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                    try await service.save(catalog)
                } catch {
                    await MainActor.run {
                        saveErrorMessage = "Failed to save catalog: \(error.localizedDescription)"
                        showSaveError = true
                    }
                }
            }
        }

        // Select the new project
        Task {
            await appState.selectProject(project)
        }

        dismiss()
    }
}

#Preview {
    CreateProjectSheet(appState: AppState())
        .preferredColorScheme(.dark)
}
