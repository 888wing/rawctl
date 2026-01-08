//
//  MetadataBar.swift
//  rawctl
//
//  Rating, color labels, flags, and tags UI
//

import SwiftUI

/// Compact metadata bar for photo organization
struct MetadataBar: View {
    @Binding var recipe: EditRecipe
    
    @State private var newTag = ""
    @State private var showTagInput = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Rating stars
            HStack(spacing: 4) {
                Text("Rating")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            recipe.rating = recipe.rating == star ? 0 : star
                        }
                    } label: {
                        Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                            .foregroundColor(star <= recipe.rating ? .yellow : .gray.opacity(0.4))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            
            // Flag buttons
            HStack(spacing: 4) {
                Text("Flag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                ForEach(Flag.allCases, id: \.self) { flag in
                    Button {
                        withAnimation {
                            recipe.flag = recipe.flag == flag ? .none : flag
                        }
                    } label: {
                        Image(systemName: flagIcon(for: flag))
                            .foregroundColor(flagColor(for: flag, selected: recipe.flag == flag))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(recipe.flag == flag ? flagColor(for: flag, selected: true).opacity(0.2) : Color.clear)
                    .cornerRadius(4)
                }
                
                Spacer()
            }
            
            // Color labels
            HStack(spacing: 4) {
                Text("Color")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
                
                ForEach(ColorLabel.allCases, id: \.self) { color in
                    Button {
                        withAnimation {
                            recipe.colorLabel = recipe.colorLabel == color ? .none : color
                        }
                    } label: {
                        Circle()
                            .fill(swiftUIColor(for: color))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(recipe.colorLabel == color ? Color.white : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    // Existing tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(recipe.tags, id: \.self) { tag in
                                TagChip(tag: tag) {
                                    withAnimation {
                                        recipe.tags.removeAll { $0 == tag }
                                    }
                                }
                            }
                            
                            // Add tag button
                            Button {
                                showTagInput.toggle()
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Tag input
                if showTagInput {
                    HStack {
                        TextField("New tag...", text: $newTag)
                            .textFieldStyle(.plain)
                            .font(.caption)
                            .padding(4)
                            .background(Color(white: 0.15))
                            .cornerRadius(4)
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .font(.caption)
                        .disabled(newTag.isEmpty)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty && !recipe.tags.contains(trimmed) {
            withAnimation {
                recipe.tags.append(trimmed)
            }
        }
        newTag = ""
        showTagInput = false
    }
    
    private func flagIcon(for flag: Flag) -> String {
        switch flag {
        case .none: return "flag"
        case .pick: return "flag.fill"
        case .reject: return "xmark.circle.fill"
        }
    }
    
    private func flagColor(for flag: Flag, selected: Bool) -> Color {
        switch flag {
        case .none: return selected ? .gray : .gray.opacity(0.5)
        case .pick: return selected ? .green : .gray.opacity(0.5)
        case .reject: return selected ? .red : .gray.opacity(0.5)
        }
    }
    
    private func swiftUIColor(for label: ColorLabel) -> Color {
        let c = label.color
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

/// Tag chip with remove button
struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 2) {
            Text(tag)
                .font(.system(size: 10))
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.2))
        .foregroundColor(.accentColor)
        .cornerRadius(4)
    }
}

#Preview {
    MetadataBar(recipe: .constant(EditRecipe()))
        .frame(width: 280)
        .padding()
        .preferredColorScheme(.dark)
}
