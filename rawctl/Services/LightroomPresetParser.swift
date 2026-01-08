//
//  LightroomPresetParser.swift
//  rawctl
//
//  Parse Lightroom XMP preset files and convert to EditRecipe
//

import Foundation

/// Parser for Lightroom XMP preset files
class LightroomPresetParser {
    
    /// Parse XMP file and return EditRecipe
    static func parse(from url: URL) throws -> EditRecipe {
        let data = try Data(contentsOf: url)
        return try parse(from: data)
    }
    
    /// Parse XMP data and return EditRecipe
    static func parse(from data: Data) throws -> EditRecipe {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidData
        }
        
        var recipe = EditRecipe()
        
        // Extract crs: namespace attributes
        let attributes = extractAttributes(from: xmlString)
        
        // Light adjustments
        recipe.exposure = parseDouble(attributes["crs:Exposure2012"]) ?? 0
        recipe.contrast = parseDouble(attributes["crs:Contrast2012"]) ?? 0
        recipe.highlights = parseDouble(attributes["crs:Highlights2012"]) ?? 0
        recipe.shadows = parseDouble(attributes["crs:Shadows2012"]) ?? 0
        recipe.whites = parseDouble(attributes["crs:Whites2012"]) ?? 0
        recipe.blacks = parseDouble(attributes["crs:Blacks2012"]) ?? 0
        
        // Color adjustments
        recipe.vibrance = parseDouble(attributes["crs:Vibrance"]) ?? 0
        recipe.saturation = parseDouble(attributes["crs:Saturation"]) ?? 0
        
        // White Balance (temperature and tint are Int in rawctl)
        if let temp = parseDouble(attributes["crs:Temperature"]) {
            recipe.whiteBalance.temperature = Int(temp)
        }
        if let tint = parseDouble(attributes["crs:Tint"]) {
            recipe.whiteBalance.tint = Int(tint)
        }
        
        // Professional grading
        recipe.clarity = parseDouble(attributes["crs:Clarity2012"]) ?? 0
        recipe.dehaze = parseDouble(attributes["crs:Dehaze"]) ?? 0
        recipe.texture = parseDouble(attributes["crs:Texture"]) ?? 0
        
        // Sharpening (LR uses 0-150, rawctl uses 0-100)
        if let sharpness = parseDouble(attributes["crs:Sharpness"]) {
            recipe.sharpness = sharpness * 100 / 150
        }
        recipe.noiseReduction = parseDouble(attributes["crs:LuminanceSmoothing"]) ?? 0
        
        // Grain
        recipe.grain.amount = parseDouble(attributes["crs:GrainAmount"]) ?? 0
        recipe.grain.size = parseDouble(attributes["crs:GrainSize"]) ?? 25
        recipe.grain.roughness = parseDouble(attributes["crs:GrainFrequency"]) ?? 50
        
        // Vignette
        recipe.vignette.amount = parseDouble(attributes["crs:PostCropVignetteAmount"]) ?? 0
        recipe.vignette.midpoint = parseDouble(attributes["crs:PostCropVignetteMidpoint"]) ?? 50
        recipe.vignette.feather = parseDouble(attributes["crs:PostCropVignetteFeather"]) ?? 50
        
        // Split Toning
        recipe.splitToning.highlightHue = parseDouble(attributes["crs:SplitToningHighlightHue"]) ?? 0
        recipe.splitToning.highlightSaturation = parseDouble(attributes["crs:SplitToningHighlightSaturation"]) ?? 0
        recipe.splitToning.shadowHue = parseDouble(attributes["crs:SplitToningShadowHue"]) ?? 0
        recipe.splitToning.shadowSaturation = parseDouble(attributes["crs:SplitToningShadowSaturation"]) ?? 0
        recipe.splitToning.balance = parseDouble(attributes["crs:SplitToningBalance"]) ?? 0
        
        // HSL adjustments (using correct structure: hsl.channel.property)
        recipe.hsl.red.hue = parseDouble(attributes["crs:HueAdjustmentRed"]) ?? 0
        recipe.hsl.orange.hue = parseDouble(attributes["crs:HueAdjustmentOrange"]) ?? 0
        recipe.hsl.yellow.hue = parseDouble(attributes["crs:HueAdjustmentYellow"]) ?? 0
        recipe.hsl.green.hue = parseDouble(attributes["crs:HueAdjustmentGreen"]) ?? 0
        recipe.hsl.cyan.hue = parseDouble(attributes["crs:HueAdjustmentAqua"]) ?? 0
        recipe.hsl.blue.hue = parseDouble(attributes["crs:HueAdjustmentBlue"]) ?? 0
        recipe.hsl.purple.hue = parseDouble(attributes["crs:HueAdjustmentPurple"]) ?? 0
        recipe.hsl.magenta.hue = parseDouble(attributes["crs:HueAdjustmentMagenta"]) ?? 0
        
        recipe.hsl.red.saturation = parseDouble(attributes["crs:SaturationAdjustmentRed"]) ?? 0
        recipe.hsl.orange.saturation = parseDouble(attributes["crs:SaturationAdjustmentOrange"]) ?? 0
        recipe.hsl.yellow.saturation = parseDouble(attributes["crs:SaturationAdjustmentYellow"]) ?? 0
        recipe.hsl.green.saturation = parseDouble(attributes["crs:SaturationAdjustmentGreen"]) ?? 0
        recipe.hsl.cyan.saturation = parseDouble(attributes["crs:SaturationAdjustmentAqua"]) ?? 0
        recipe.hsl.blue.saturation = parseDouble(attributes["crs:SaturationAdjustmentBlue"]) ?? 0
        recipe.hsl.purple.saturation = parseDouble(attributes["crs:SaturationAdjustmentPurple"]) ?? 0
        recipe.hsl.magenta.saturation = parseDouble(attributes["crs:SaturationAdjustmentMagenta"]) ?? 0
        
        recipe.hsl.red.luminance = parseDouble(attributes["crs:LuminanceAdjustmentRed"]) ?? 0
        recipe.hsl.orange.luminance = parseDouble(attributes["crs:LuminanceAdjustmentOrange"]) ?? 0
        recipe.hsl.yellow.luminance = parseDouble(attributes["crs:LuminanceAdjustmentYellow"]) ?? 0
        recipe.hsl.green.luminance = parseDouble(attributes["crs:LuminanceAdjustmentGreen"]) ?? 0
        recipe.hsl.cyan.luminance = parseDouble(attributes["crs:LuminanceAdjustmentAqua"]) ?? 0
        recipe.hsl.blue.luminance = parseDouble(attributes["crs:LuminanceAdjustmentBlue"]) ?? 0
        recipe.hsl.purple.luminance = parseDouble(attributes["crs:LuminanceAdjustmentPurple"]) ?? 0
        recipe.hsl.magenta.luminance = parseDouble(attributes["crs:LuminanceAdjustmentMagenta"]) ?? 0
        
        // Camera Calibration
        recipe.calibration.shadowTint = parseDouble(attributes["crs:ShadowTint"]) ?? 0
        recipe.calibration.redHue = parseDouble(attributes["crs:RedHue"]) ?? 0
        recipe.calibration.redSaturation = parseDouble(attributes["crs:RedSaturation"]) ?? 0
        recipe.calibration.greenHue = parseDouble(attributes["crs:GreenHue"]) ?? 0
        recipe.calibration.greenSaturation = parseDouble(attributes["crs:GreenSaturation"]) ?? 0
        recipe.calibration.blueHue = parseDouble(attributes["crs:BlueHue"]) ?? 0
        recipe.calibration.blueSaturation = parseDouble(attributes["crs:BlueSaturation"]) ?? 0
        
        // Perspective
        recipe.perspective.vertical = parseDouble(attributes["crs:PerspectiveVertical"]) ?? 0
        recipe.perspective.horizontal = parseDouble(attributes["crs:PerspectiveHorizontal"]) ?? 0
        recipe.perspective.rotate = parseDouble(attributes["crs:PerspectiveRotate"]) ?? 0
        recipe.perspective.scale = 100 + (parseDouble(attributes["crs:PerspectiveScale"]) ?? 0)
        
        print("[LightroomParser] Imported preset with \(countNonZeroValues(recipe)) adjustments")
        
        return recipe
    }
    
    /// Extract all crs: attributes from XMP string
    private static func extractAttributes(from xml: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        // Match patterns like crs:Exposure2012="+0.50" or crs:Exposure2012="0"
        let pattern = #"(crs:\w+)=\"([^\"]*)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return attributes
        }
        
        let range = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: range)
        
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: xml),
               let valueRange = Range(match.range(at: 2), in: xml) {
                let key = String(xml[keyRange])
                let value = String(xml[valueRange])
                attributes[key] = value
            }
        }
        
        return attributes
    }
    
    /// Parse string to Double, handling +/- prefix
    private static func parseDouble(_ str: String?) -> Double? {
        guard let str = str else { return nil }
        return Double(str.trimmingCharacters(in: .whitespaces))
    }
    
    /// Count non-zero values for logging
    private static func countNonZeroValues(_ recipe: EditRecipe) -> Int {
        var count = 0
        if recipe.exposure != 0 { count += 1 }
        if recipe.contrast != 0 { count += 1 }
        if recipe.highlights != 0 { count += 1 }
        if recipe.shadows != 0 { count += 1 }
        if recipe.whites != 0 { count += 1 }
        if recipe.blacks != 0 { count += 1 }
        if recipe.vibrance != 0 { count += 1 }
        if recipe.saturation != 0 { count += 1 }
        if recipe.clarity != 0 { count += 1 }
        if recipe.dehaze != 0 { count += 1 }
        if recipe.texture != 0 { count += 1 }
        if recipe.grain.hasEffect { count += 1 }
        if recipe.vignette.hasEffect { count += 1 }
        if recipe.splitToning.hasEffect { count += 1 }
        if recipe.hsl.hasEdits { count += 1 }
        if recipe.calibration.hasEdits { count += 1 }
        return count
    }
    
    enum ParserError: LocalizedError {
        case invalidData
        case missingAttributes
        
        var errorDescription: String? {
            switch self {
            case .invalidData: return "Invalid XMP data"
            case .missingAttributes: return "No Lightroom attributes found"
            }
        }
    }
}

/// Preset file info for UI display
struct PresetInfo: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var recipe: EditRecipe?
}
