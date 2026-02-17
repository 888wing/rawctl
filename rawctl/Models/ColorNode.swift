//
//  ColorNode.swift
//  rawctl
//
//  Node-based color grading system - Core data models
//  Inspired by DaVinci Resolve's node-based workflow
//

import Foundation
import SwiftUI

// MARK: - Color Node

/// A single color grading node in the node graph
struct ColorNode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: NodeType
    var adjustments: EditRecipe
    var isEnabled: Bool = true
    var blendMode: BlendMode = .normal
    var opacity: Double = 1.0
    var mask: NodeMask?
    var position: CGPoint = .zero  // Position in node editor UI
    
    init(
        id: UUID = UUID(),
        name: String = "Node",
        type: NodeType = .serial,
        adjustments: EditRecipe = EditRecipe()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.adjustments = adjustments
    }
    
    /// Node type determines how it connects in the graph
    enum NodeType: String, Codable, CaseIterable {
        case input      // Source image input
        case serial     // Serial processing (in → out)
        case parallel   // Parallel processing (needs blend)
        case lut        // LUT lookup table
        case output     // Final output
        
        var displayName: String {
            switch self {
            case .input: return "Input"
            case .serial: return "Serial"
            case .parallel: return "Parallel"
            case .lut: return "LUT"
            case .output: return "Output"
            }
        }
        
        var icon: String {
            switch self {
            case .input: return "arrow.right.circle"
            case .serial: return "slider.horizontal.3"
            case .parallel: return "square.on.square"
            case .lut: return "cube"
            case .output: return "arrow.down.circle"
            }
        }
    }
}

// MARK: - Blend Mode

/// Blend modes for combining node outputs
enum BlendMode: String, Codable, CaseIterable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight
    case colorDodge
    case colorBurn
    case luminosity
    case color
    case saturation
    case hue
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .overlay: return "Overlay"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .colorDodge: return "Color Dodge"
        case .colorBurn: return "Color Burn"
        case .luminosity: return "Luminosity"
        case .color: return "Color"
        case .saturation: return "Saturation"
        case .hue: return "Hue"
        }
    }
    
    /// CIFilter blend mode key (if applicable)
    var ciFilterName: String? {
        switch self {
        case .normal: return nil
        case .multiply: return "CIMultiplyBlendMode"
        case .screen: return "CIScreenBlendMode"
        case .overlay: return "CIOverlayBlendMode"
        case .softLight: return "CISoftLightBlendMode"
        case .hardLight: return "CIHardLightBlendMode"
        case .colorDodge: return "CIColorDodgeBlendMode"
        case .colorBurn: return "CIColorBurnBlendMode"
        case .luminosity: return "CILuminosityBlendMode"
        case .color: return "CIColorBlendMode"
        case .saturation: return "CISaturationBlendMode"
        case .hue: return "CIHueBlendMode"
        }
    }
}

// MARK: - Node Mask

/// Mask for selective color grading within a node
struct NodeMask: Codable, Equatable {
    var type: MaskType
    var feather: Double = 20.0    // Edge feather amount (0-100)
    var invert: Bool = false
    
    /// Mask type determines how pixels are selected
    enum MaskType: Codable, Equatable {
        case luminosity(min: Double, max: Double)           // Select by brightness range
        case color(hue: Double, hueRange: Double, satMin: Double)  // Select by color
        case radial(centerX: Double, centerY: Double, radius: Double)  // Circular gradient
        case linear(angle: Double, position: Double, falloff: Double)  // Linear gradient
        
        var displayName: String {
            switch self {
            case .luminosity: return "Luminosity Mask"
            case .color: return "Color Mask"
            case .radial: return "Radial Mask"
            case .linear: return "Linear Mask"
            }
        }
    }
    
    /// Create a luminosity mask (highlights, midtones, shadows)
    static func highlights() -> NodeMask {
        NodeMask(type: .luminosity(min: 0.6, max: 1.0))
    }
    
    static func midtones() -> NodeMask {
        NodeMask(type: .luminosity(min: 0.25, max: 0.75))
    }
    
    static func shadows() -> NodeMask {
        NodeMask(type: .luminosity(min: 0.0, max: 0.4))
    }
}

// MARK: - Node Connection

/// Connection between two nodes
struct NodeConnection: Codable, Equatable, Identifiable {
    let id: UUID
    var sourceNodeId: UUID
    var destinationNodeId: UUID
    var sourceOutput: Int = 0      // Output port index
    var destinationInput: Int = 0  // Input port index
    
    init(from source: UUID, to destination: UUID) {
        self.id = UUID()
        self.sourceNodeId = source
        self.destinationNodeId = destination
    }
}

// MARK: - Node Graph

/// A complete node graph representing the color grading pipeline
struct NodeGraph: Codable, Equatable {
    var nodes: [ColorNode] = []
    var connections: [NodeConnection] = []
    
    /// Create a default graph with input → serial → output
    static func createDefault() -> NodeGraph {
        let inputNode = ColorNode(name: "Input", type: .input)
        let colorNode = ColorNode(name: "Primary", type: .serial)
        let outputNode = ColorNode(name: "Output", type: .output)
        
        var graph = NodeGraph()
        graph.nodes = [inputNode, colorNode, outputNode]
        graph.connections = [
            NodeConnection(from: inputNode.id, to: colorNode.id),
            NodeConnection(from: colorNode.id, to: outputNode.id)
        ]
        
        return graph
    }
    
    /// Add a new node to the graph
    mutating func addNode(_ node: ColorNode) {
        nodes.append(node)
    }
    
    /// Remove a node and its connections
    mutating func removeNode(id: UUID) {
        nodes.removeAll { $0.id == id }
        connections.removeAll { $0.sourceNodeId == id || $0.destinationNodeId == id }
    }
    
    /// Connect two nodes
    mutating func connect(from source: UUID, to destination: UUID) {
        let connection = NodeConnection(from: source, to: destination)
        connections.append(connection)
    }
    
    /// Get nodes in topological order for processing
    func topologicallySorted() -> [ColorNode] {
        var result: [ColorNode] = []
        var visited: Set<UUID> = []
        var nodeMap: [UUID: ColorNode] = [:]
        
        for node in nodes {
            nodeMap[node.id] = node
        }
        
        // Build adjacency list
        var outgoing: [UUID: [UUID]] = [:]
        for connection in connections {
            outgoing[connection.sourceNodeId, default: []].append(connection.destinationNodeId)
        }
        
        // Find input nodes (no incoming connections)
        let destinationIds = Set(connections.map { $0.destinationNodeId })
        let inputNodes = nodes.filter { !destinationIds.contains($0.id) }
        
        // DFS traversal
        func visit(_ nodeId: UUID) {
            guard !visited.contains(nodeId), let node = nodeMap[nodeId] else { return }
            visited.insert(nodeId)
            result.append(node)
            
            for nextId in outgoing[nodeId] ?? [] {
                visit(nextId)
            }
        }
        
        for inputNode in inputNodes {
            visit(inputNode.id)
        }
        
        return result
    }
    
    /// Get enabled nodes only
    var enabledNodes: [ColorNode] {
        topologicallySorted().filter { $0.isEnabled }
    }
    
    /// Check if graph has any edits
    var hasEdits: Bool {
        nodes.contains { $0.type == .serial && $0.adjustments.hasEdits }
    }
}

// MARK: - CGPoint Codable
// `CGPoint` is already `Codable` via CoreGraphics; avoid a duplicate conformance.
