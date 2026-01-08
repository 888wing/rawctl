//
//  ProjectsSection.swift
//  rawctl
//
//  Projects section of the sidebar with month grouping
//

import SwiftUI

/// Projects section showing grouped projects
struct ProjectsSection: View {
    @ObservedObject var appState: AppState
    @State private var isExpanded = true
    @State private var expandedMonths: Set<String> = []
    @State private var showCreateProject = false

    var body: some View {
        DisclosureGroup("Projects", isExpanded: $isExpanded) {
            VStack(spacing: 4) {
                if let catalog = appState.catalog {
                    ForEach(catalog.projectsByMonth, id: \.month) { group in
                        MonthGroup(
                            month: group.month,
                            projects: group.projects,
                            isExpanded: expandedMonths.contains(group.month),
                            selectedProject: appState.selectedProject,
                            onToggle: { toggleMonth(group.month) },
                            onSelect: { project in
                                Task {
                                    await appState.selectProject(project)
                                }
                            },
                            onUpdateStatus: updateProjectStatus
                        )
                    }

                    if catalog.projects.isEmpty {
                        Text("No projects yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }

                // Create Project button
                Button {
                    showCreateProject = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text("Create Project")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            // Expand current month by default
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            expandedMonths.insert(formatter.string(from: Date()))
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectSheet(appState: appState)
        }
    }

    private func toggleMonth(_ month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
    }

    private func updateProjectStatus(_ project: Project, to status: ProjectStatus) {
        guard var catalog = appState.catalog else { return }
        var updatedProject = project
        updatedProject.status = status
        catalog.updateProject(updatedProject)
        appState.catalog = catalog

        Task {
            do {
                let service = CatalogService(catalogPath: CatalogService.defaultCatalogPath)
                try await service.save(catalog)
            } catch {
                print("[ProjectsSection] Failed to save catalog: \(error.localizedDescription)")
            }
        }
    }
}

/// Month grouping for projects
struct MonthGroup: View {
    let month: String
    let projects: [Project]
    let isExpanded: Bool
    let selectedProject: Project?
    let onToggle: () -> Void
    let onSelect: (Project) -> Void
    var onUpdateStatus: ((Project, ProjectStatus) -> Void)?

    var body: some View {
        VStack(spacing: 2) {
            // Month header
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Text(formattedMonth)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(projects.count)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            // Projects in this month
            if isExpanded {
                ForEach(projects) { project in
                    ProjectRow(
                        project: project,
                        isSelected: selectedProject?.id == project.id,
                        onSelect: { onSelect(project) },
                        onUpdateStatus: onUpdateStatus
                    )
                }
            }
        }
    }

    private var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: month) else { return month }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMMM yyyy"
        return displayFormatter.string(from: date)
    }
}

/// Single project row
struct ProjectRow: View {
    let project: Project
    let isSelected: Bool
    let onSelect: () -> Void
    var onUpdateStatus: ((Project, ProjectStatus) -> Void)?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: project.projectType.icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .accentColor : .primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("\(project.totalPhotos) photos")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)

                        Circle()
                            .fill(Color(
                                red: project.status.color.r,
                                green: project.status.color.g,
                                blue: project.status.color.b
                            ))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .padding(.leading, 16)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open in Finder") {
                if let folder = project.sourceFolders.first {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                }
            }

            Divider()

            Menu("Set Status") {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        onUpdateStatus?(project, status)
                    }
                }
            }

            Divider()

            Button("Archive Project", role: .destructive) {
                onUpdateStatus?(project, .archived)
            }
        }
    }
}

#Preview {
    ProjectsSection(appState: AppState())
        .frame(width: 220)
        .preferredColorScheme(.dark)
}
