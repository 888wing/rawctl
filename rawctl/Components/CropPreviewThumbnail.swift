//
//  CropPreviewThumbnail.swift
//  rawctl
//
//  Preview thumbnail for crop area in the right panel
//

import SwiftUI

/// Crop preview thumbnail with visual overlay
struct CropPreviewThumbnail: View {
    @Binding var crop: Crop
    let previewImage: NSImage?
    let onTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))

                if let image = previewImage {
                    // Scaled-down preview image
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            // Crop frame overlay (simplified)
                            if crop.isEnabled {
                                CropRectOverlay(rect: crop.rect)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                } else {
                    // No image placeholder
                    VStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Tap hint when no crop
                if !crop.isEnabled && previewImage != nil {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Click to crop")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(6)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
        .frame(height: 80)
    }
}

/// Simple crop rect overlay for thumbnail
private struct CropRectOverlay: View {
    let rect: CropRect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed outside area
                Color.black.opacity(0.4)
                    .mask {
                        Rectangle()
                            .overlay {
                                Rectangle()
                                    .frame(
                                        width: geo.size.width * rect.w,
                                        height: geo.size.height * rect.h
                                    )
                                    .position(
                                        x: geo.size.width * (rect.x + rect.w / 2),
                                        y: geo.size.height * (rect.y + rect.h / 2)
                                    )
                                    .blendMode(.destinationOut)
                            }
                    }

                // White border around crop area
                Rectangle()
                    .stroke(Color.white, lineWidth: 1)
                    .frame(
                        width: geo.size.width * rect.w,
                        height: geo.size.height * rect.h
                    )
                    .position(
                        x: geo.size.width * (rect.x + rect.w / 2),
                        y: geo.size.height * (rect.y + rect.h / 2)
                    )
            }
        }
    }
}

#Preview("With Crop") {
    CropPreviewThumbnail(
        crop: .constant(Crop(isEnabled: true, rect: CropRect(x: 0.1, y: 0.2, w: 0.6, h: 0.5))),
        previewImage: nil,
        onTap: {}
    )
    .frame(width: 280)
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("No Crop") {
    CropPreviewThumbnail(
        crop: .constant(Crop()),
        previewImage: nil,
        onTap: {}
    )
    .frame(width: 280)
    .padding()
    .preferredColorScheme(.dark)
}
