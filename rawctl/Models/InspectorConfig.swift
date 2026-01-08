//
//  InspectorConfig.swift
//  rawctl
//
//  Inspector panel visibility configuration
//

import SwiftUI
import Combine

/// All available inspector panels
enum InspectorPanel: String, CaseIterable, Identifiable, Codable {
    case organization = "Organization"
    case light = "Light"
    case toneCurve = "Tone Curve"
    case rgbCurves = "RGB Curves"
    case whiteBalance = "White Balance"
    case color = "Color"
    case hsl = "HSL"
    case composition = "Composition"
    case effects = "Effects"
    case splitToning = "Split Toning"
    case grain = "Grain"
    case transform = "Transform"
    case lensCorrections = "Lens Corrections"
    case calibration = "Calibration"
    case aiGeneration = "AI Generation"
    case aiLayers = "AI Layers"

    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .organization: return "folder"
        case .light: return "sun.max"
        case .toneCurve: return "chart.line.uptrend.xyaxis"
        case .rgbCurves: return "waveform"
        case .whiteBalance: return "thermometer.sun"
        case .color: return "paintpalette"
        case .hsl: return "slider.horizontal.3"
        case .composition: return "crop"
        case .effects: return "sparkles"
        case .splitToning: return "circle.lefthalf.filled"
        case .grain: return "square.3.layers.3d"
        case .transform: return "perspective"
        case .lensCorrections: return "camera.aperture"
        case .calibration: return "gearshape"
        case .aiGeneration: return "wand.and.stars"
        case .aiLayers: return "square.3.layers.3d"
        }
    }

    /// Default visibility for each panel
    var defaultVisible: Bool {
        switch self {
        case .organization, .light, .toneCurve, .color, .hsl, .composition, .effects, .whiteBalance, .aiGeneration, .aiLayers:
            return true
        case .rgbCurves, .splitToning, .grain, .transform, .lensCorrections, .calibration:
            return false  // Advanced panels hidden by default
        }
    }
}

/// Observable configuration for inspector panels
class InspectorConfig: ObservableObject {
    static let shared = InspectorConfig()
    
    private let userDefaultsKey = "com.rawctl.inspectorPanelVisibility"
    
    @Published var visiblePanels: Set<InspectorPanel> {
        didSet {
            saveToUserDefaults()
        }
    }
    
    private init() {
        // Load from UserDefaults or use defaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let panels = try? JSONDecoder().decode(Set<InspectorPanel>.self, from: data) {
            self.visiblePanels = panels
        } else {
            // Default: show commonly used panels
            self.visiblePanels = Set(InspectorPanel.allCases.filter { $0.defaultVisible })
        }
    }
    
    func isVisible(_ panel: InspectorPanel) -> Bool {
        visiblePanels.contains(panel)
    }
    
    func toggle(_ panel: InspectorPanel) {
        if visiblePanels.contains(panel) {
            visiblePanels.remove(panel)
        } else {
            visiblePanels.insert(panel)
        }
    }
    
    func setVisible(_ panel: InspectorPanel, visible: Bool) {
        if visible {
            visiblePanels.insert(panel)
        } else {
            visiblePanels.remove(panel)
        }
    }
    
    func showAll() {
        visiblePanels = Set(InspectorPanel.allCases)
    }
    
    func resetToDefaults() {
        visiblePanels = Set(InspectorPanel.allCases.filter { $0.defaultVisible })
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(visiblePanels) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

/// Panel visibility customization sheet
struct InspectorCustomizeSheet: View {
    @ObservedObject var config = InspectorConfig.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Customize Inspector")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // Panel list
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(InspectorPanel.allCases) { panel in
                        PanelToggleRow(panel: panel, isVisible: config.isVisible(panel)) {
                            config.toggle(panel)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer actions
            HStack {
                Button("Show All") {
                    config.showAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Reset Defaults") {
                    config.resetToDefaults()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 300, height: 500)
        .background(.ultraThinMaterial)
    }
}

/// Single panel toggle row
private struct PanelToggleRow: View {
    let panel: InspectorPanel
    let isVisible: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: panel.icon)
                    .frame(width: 20)
                    .foregroundColor(isVisible ? .accentColor : .secondary)
                
                Text(panel.rawValue)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isVisible ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isVisible ? .accentColor : .secondary.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isVisible ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InspectorCustomizeSheet()
        .preferredColorScheme(.dark)
}
