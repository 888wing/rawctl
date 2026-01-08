//
//  EXIFViewerWindow.swift
//  rawctl
//
//  Complete EXIF metadata viewer with search functionality
//

import SwiftUI

/// EXIF Viewer Window for displaying complete metadata
struct EXIFViewerWindow: View {
    @ObservedObject var appState: AppState
    let asset: PhotoAsset
    @Environment(\.dismiss) private var dismiss
    
    @State private var exifData: EXIFData?
    @State private var isLoading = true
    @State private var fileSize: Int64 = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EXIF Info")
                    .font(.headline)
                Text("- \(asset.filename)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()
            
            if isLoading {
                Spacer()
                ProgressView("Loading EXIF...")
                Spacer()
            } else if let exif = exifData {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Camera Section
                        EXIFSection(title: "Camera", icon: "camera") {
                            EXIFRow(label: "Make", value: exif.cameraMake) {
                                searchExact(field: .cameraMake, value: exif.cameraMake)
                            }
                            EXIFRow(label: "Model", value: exif.cameraModel) {
                                searchExact(field: .cameraModel, value: exif.cameraModel)
                            }
                            EXIFRow(label: "Lens", value: exif.lens) {
                                searchExact(field: .lens, value: exif.lens)
                            }
                            EXIFRow(label: "Software", value: exif.software, searchable: false)
                        }
                        
                        Divider()
                        
                        // Exposure Section
                        EXIFSection(title: "Exposure", icon: "f.cursive") {
                            EXIFRowWithRange(
                                label: "ISO",
                                value: exif.isoString,
                                rawValue: exif.iso,
                                onExact: { searchExact(field: .iso, value: exif.iso) },
                                onSimilar: { searchSimilarISO(exif.iso) }
                            )
                            EXIFRowWithRange(
                                label: "Aperture",
                                value: exif.apertureString,
                                rawValue: exif.aperture,
                                onExact: { searchExact(field: .aperture, value: exif.aperture) },
                                onSimilar: { searchSimilarAperture(exif.aperture) }
                            )
                            EXIFRowWithRange(
                                label: "Shutter",
                                value: exif.shutterSpeedString,
                                rawValue: exif.shutterSpeed,
                                onExact: { searchExact(field: .shutterSpeed, value: exif.shutterSpeed) },
                                onSimilar: nil
                            )
                            EXIFRow(label: "Focal Length", value: exif.focalLengthString) {
                                searchExact(field: .focalLength, value: exif.focalLength)
                            }
                            EXIFRow(label: "Exposure Comp", value: exif.exposureCompensation.map { String(format: "%+.1f EV", $0) }, searchable: false)
                            EXIFRow(label: "Metering", value: exif.meteringMode, searchable: false)
                            EXIFRow(label: "Flash", value: exif.flash, searchable: false)
                        }
                        
                        Divider()
                        
                        // Date/Time Section
                        EXIFSection(title: "Date & Time", icon: "calendar") {
                            if let date = exif.dateTimeOriginal {
                                EXIFRowWithRange(
                                    label: "Date Captured",
                                    value: formatDate(date),
                                    rawValue: date,
                                    onExact: { searchSameDay(date) },
                                    onSimilar: { searchSameMonth(date) }
                                )
                            }
                        }
                        
                        // GPS Section (if available)
                        if exif.hasGPS {
                            Divider()
                            
                            EXIFSection(title: "Location", icon: "location") {
                                EXIFRow(label: "Coordinates", value: exif.gpsCoordinateString) {
                                    searchNearby(lat: exif.gpsLatitude!, lon: exif.gpsLongitude!)
                                }
                                EXIFRow(label: "Altitude", value: exif.gpsAltitude.map { String(format: "%.1f m", $0) }, searchable: false)
                            }
                        }
                        
                        Divider()
                        
                        // File Section
                        EXIFSection(title: "File Info", icon: "doc") {
                            EXIFRow(label: "Dimensions", value: exif.dimensionsString, searchable: false)
                            EXIFRow(label: "Megapixels", value: exif.megapixels.map { String(format: "%.1f MP", $0) }, searchable: false)
                            EXIFRow(label: "File Size", value: formatFileSize(fileSize), searchable: false)
                            EXIFRow(label: "Color Space", value: exif.colorSpace, searchable: false)
                            EXIFRow(label: "Bit Depth", value: exif.bitDepth.map { "\($0) bit" }, searchable: false)
                            EXIFRow(label: "Copyright", value: exif.copyright, searchable: false)
                            EXIFRow(label: "Artist", value: exif.artist, searchable: false)
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("Unable to read EXIF")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 450, minHeight: 500)
        .task {
            await loadEXIF()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadEXIF() async {
        isLoading = true
        fileSize = asset.fileSize
        exifData = await EXIFService.shared.extractEXIF(from: asset.url)
        isLoading = false
    }
    
    // MARK: - Search Actions
    
    private func searchExact<T>(field: EXIFSearchField, value: T?) {
        guard value != nil else { return }
        appState.setEXIFFilter(field: field, value: value, mode: .exact)
        dismiss()
    }
    
    private func searchSimilarISO(_ iso: Int?) {
        guard let iso = iso else { return }
        // Search within 1 stop range
        let lower = max(50, iso / 2)
        let upper = iso * 2
        appState.setEXIFFilter(field: .iso, range: lower...upper)
        dismiss()
    }
    
    private func searchSimilarAperture(_ aperture: Double?) {
        guard let f = aperture else { return }
        // Search within 1 stop range
        let lower = f / 1.4
        let upper = f * 1.4
        appState.setEXIFFilter(field: .aperture, range: lower...upper)
        dismiss()
    }
    
    private func searchSameDay(_ date: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        appState.setEXIFFilter(field: .dateTimeOriginal, range: start...end)
        dismiss()
    }
    
    private func searchSameMonth(_ date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!
        appState.setEXIFFilter(field: .dateTimeOriginal, range: start...end)
        dismiss()
    }
    
    private func searchNearby(lat: Double, lon: Double) {
        appState.setEXIFFilter(field: .gpsLocation, location: (lat, lon), radius: 1.0) // 1km radius
        dismiss()
    }
    
    // MARK: - Formatting
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Views

struct EXIFSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            content
        }
    }
}

struct EXIFRow: View {
    let label: String
    let value: String?
    var searchable: Bool = true
    var onSearch: (() -> Void)?
    
    init(label: String, value: String?, searchable: Bool = true, onSearch: (() -> Void)? = nil) {
        self.label = label
        self.value = value
        self.searchable = searchable
        self.onSearch = onSearch
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value ?? "—")
                .font(.caption)
                .foregroundColor(value != nil ? .primary : .secondary)
            
            Spacer()
            
            if searchable && value != nil, let action = onSearch {
                Button {
                    action()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "magnifyingglass")
                        Text("Search Similar")
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

struct EXIFRowWithRange<T>: View {
    let label: String
    let value: String?
    let rawValue: T?
    var onExact: (() -> Void)?
    var onSimilar: (() -> Void)?
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value ?? "—")
                .font(.caption)
                .foregroundColor(value != nil ? .primary : .secondary)
            
            Spacer()
            
            if value != nil {
                HStack(spacing: 4) {
                    if let action = onExact {
                        Button {
                            action()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "equal")
                                Text("Same")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if let action = onSimilar {
                        Button {
                            action()
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "plusminus")
                                Text("Similar")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - EXIF Search Types

enum EXIFSearchField: String {
    case cameraMake
    case cameraModel
    case lens
    case iso
    case aperture
    case shutterSpeed
    case focalLength
    case dateTimeOriginal
    case gpsLocation
}

enum EXIFSearchMode {
    case exact
    case range
}
