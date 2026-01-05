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
    @State private var sourceFolder: URL?
    @State private var notes: String = ""

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

                Section("Source Folder") {
                    HStack {
                        if let folder = sourceFolder {
                            Text(folder.path)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("No folder selected")
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Choose...") {
                            selectFolder()
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
        .onAppear {
            // Auto-generate name from date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            projectName = formatter.string(from: shootDate)
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select the folder containing your photos"

        if panel.runModal() == .OK {
            sourceFolder = panel.url

            // Update project name from folder if not set
            if projectName.isEmpty || projectName.contains("-") {
                projectName = panel.url?.lastPathComponent ?? projectName
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

        if let folder = sourceFolder {
            project.sourceFolders = [folder]
        }

        // Add to catalog
        if var catalog = appState.catalog {
            catalog.addProject(project)
            appState.catalog = catalog

            // Save catalog
            Task {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                try? await service.save(catalog)
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
