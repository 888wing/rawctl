//
//  ProfilePicker.swift
//  rawctl
//
//  Camera profile selection UI component
//

import SwiftUI

/// Picker for selecting camera profiles
struct ProfilePicker: View {
    @Binding var selectedProfileId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profile")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(BuiltInProfile.allCases) { profile in
                    ProfileButton(
                        profile: profile,
                        isSelected: selectedProfileId == profile.rawValue,
                        action: {
                            selectedProfileId = profile.rawValue
                        }
                    )
                }
            }
        }
    }
}

/// Individual profile selection button
private struct ProfileButton: View {
    let profile: BuiltInProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: profile.icon)
                    .font(.system(size: 16))

                Text(profile.displayName.replacingOccurrences(of: "rawctl ", with: ""))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .primary)
    }
}

#Preview {
    ProfilePicker(selectedProfileId: .constant(BuiltInProfile.neutral.rawValue))
        .padding()
        .frame(width: 280)
}
