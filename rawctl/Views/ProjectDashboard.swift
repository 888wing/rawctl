//
//  ProjectDashboard.swift
//  rawctl
//
//  Dashboard showing project progress and statistics
//

import SwiftUI

/// Dashboard view for project progress
struct ProjectDashboard: View {
    @ObservedObject var appState: AppState

    let project: Project

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with project info
                projectHeader

                // Progress stats
                progressCards

                // Quick actions
                quickActions

                // Recent activity
                recentActivity
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var projectHeader: some View {
        HStack(spacing: 16) {
            // Project icon
            Image(systemName: project.projectType.icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
                .frame(width: 60, height: 60)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.title2.bold())

                HStack(spacing: 8) {
                    if let client = project.clientName {
                        Text(client)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(project.shootDate.formatted(.dateTime.month().day().year()))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            Spacer()

            // Status badge
            statusBadge
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(
                    red: project.status.color.r,
                    green: project.status.color.g,
                    blue: project.status.color.b
                ))
                .frame(width: 8, height: 8)

            Text(project.status.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.15))
        .cornerRadius(12)
    }

    // MARK: - Progress Cards

    private var progressCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Total",
                value: "\(project.totalPhotos)",
                icon: "photo.on.rectangle",
                color: .blue
            )

            StatCard(
                title: "Rated",
                value: "\(project.ratedPhotos)",
                icon: "star.fill",
                color: .yellow,
                progress: progressRated
            )

            StatCard(
                title: "Picks",
                value: "\(project.flaggedPhotos)",
                icon: "flag.fill",
                color: .green
            )

            StatCard(
                title: "Exported",
                value: "\(project.exportedPhotos)",
                icon: "arrow.up.doc",
                color: .purple,
                progress: progressExported
            )
        }
    }

    private var progressRated: Double {
        guard project.totalPhotos > 0 else { return 0 }
        return Double(project.ratedPhotos) / Double(project.totalPhotos)
    }

    private var progressExported: Double {
        guard project.totalPhotos > 0 else { return 0 }
        return Double(project.exportedPhotos) / Double(project.totalPhotos)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                DashboardActionButton(
                    title: "Start Culling",
                    icon: "rectangle.on.rectangle",
                    color: .orange
                ) {
                    // Open survey mode
                }

                DashboardActionButton(
                    title: "Export Picks",
                    icon: "square.and.arrow.up",
                    color: .green
                ) {
                    // Export picks
                }

                DashboardActionButton(
                    title: "Open in Finder",
                    icon: "folder",
                    color: .blue
                ) {
                    if let folder = project.sourceFolders.first {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path)
                    }
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)

            VStack(spacing: 8) {
                ActivityRow(
                    icon: "photo",
                    text: "Project created",
                    date: project.createdAt
                )

                if project.updatedAt != project.createdAt {
                    ActivityRow(
                        icon: "pencil",
                        text: "Last modified",
                        date: project.updatedAt
                    )
                }
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

/// Stat card component
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title.bold())

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
            }
        }
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

/// Action button component for dashboard
struct DashboardActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.15))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

/// Activity row component
struct ActivityRow: View {
    let icon: String
    let text: String
    let date: Date

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(text)
            Spacer()
            Text(date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProjectDashboard(
        appState: AppState(),
        project: Project(name: "Test Wedding", shootDate: Date(), projectType: .wedding)
    )
    .frame(width: 600, height: 500)
    .preferredColorScheme(.dark)
}
