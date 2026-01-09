//
//  AboutView.swift
//  rawctl
//
//  About page with version info and links
//

import SwiftUI

struct AboutView: View {
    @State private var showingWhatsNew = false
    @State private var showingVersionHistory = false

    var body: some View {
        Form {
            // App Info Section
            Section {
                VStack(spacing: 16) {
                    // App icon
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                    // App name and version
                    VStack(spacing: 4) {
                        Text("rawctl")
                            .font(.title.bold())

                        HStack(spacing: 8) {
                            Text("Version \(VersionTracker.currentVersion)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("(\(VersionTracker.buildNumber))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Description
                    Text("Professional RAW photo editor for macOS")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Quick Actions
            Section {
                Button {
                    showingWhatsNew = true
                } label: {
                    Label("What's New in v\(VersionTracker.currentVersion)", systemImage: "sparkles")
                }

                Button {
                    showingVersionHistory = true
                } label: {
                    Label("Version History", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("Release Notes")
            }

            // Links
            Section {
                Link(destination: URL(string: "https://rawctl.com")!) {
                    Label("Website", systemImage: "globe")
                }

                Link(destination: URL(string: "https://github.com/nicholasleexyz/rawctl")!) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "https://rawctl.com/#pricing")!) {
                    Label("Pricing & Plans", systemImage: "creditcard")
                }
            } header: {
                Text("Links")
            }

            // Legal
            Section {
                Link(destination: URL(string: "https://rawctl.com/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: URL(string: "https://rawctl.com/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            } header: {
                Text("Legal")
            }

            // Credits
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Made with")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 16) {
                        TechBadge(name: "SwiftUI", color: .blue)
                        TechBadge(name: "Core Image", color: .purple)
                        TechBadge(name: "CIRAWFilter", color: .orange)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Built With")
            }

            // Copyright
            Section {
                VStack(spacing: 4) {
                    Text("rawctl")
                        .font(.caption.bold())

                    Text("Copyright 2024-2025 Nicholas Lee")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text("Open source under MIT License")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView(release: ReleaseHistory.latest) {
                showingWhatsNew = false
            }
        }
        .sheet(isPresented: $showingVersionHistory) {
            VersionHistoryView()
        }
    }
}

// MARK: - Tech Badge

private struct TechBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}
