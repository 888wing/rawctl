//
//  EditRecipe.swift
//  rawctl
//
//  Non-destructive editing parameters matching sidecar JSON schema v1
//

import Foundation

/// Edit recipe matching sidecar JSON schema version 1
struct EditRecipe: Codable, Equatable {
    // Light adjustments
    var exposure: Double = 0.0        // [-5, +5] stops
    var contrast: Double = 0.0        // [-100, +100]
    var highlights: Double = 0.0      // [-100, +100]
    var shadows: Double = 0.0         // [-100, +100]
    var whites: Double = 0.0          // [-100, +100]
    var blacks: Double = 0.0          // [-100, +100]
    
    // Tone Curve
    var toneCurve: ToneCurve = ToneCurve()
    
    // White Balance (absolute Kelvin)
    var whiteBalance: WhiteBalance = WhiteBalance()
    
    // Color adjustments (relative)
    var vibrance: Double = 0.0        // [-100, +100]
    var saturation: Double = 0.0      // [-100, +100]
    
    // Composition
    var crop: Crop = Crop()
    
    // MARK: - Advanced Effects (P0)
    var rgbCurves: RGBCurves = RGBCurves()
    var vignette: Vignette = Vignette()
    var splitToning: SplitToning = SplitToning()
    var sharpness: Double = 0         // 0-100
    var noiseReduction: Double = 0    // 0-100
    var grain: Grain = Grain()        // Film grain effect
    
    // MARK: - Lens Corrections
    var chromaticAberration: ChromaticAberration = ChromaticAberration()
    var perspective: Perspective = Perspective()
    
    // MARK: - Professional Color Grading
    var hsl: HSLAdjustment = HSLAdjustment()  // Per-color HSL adjustment
    var clarity: Double = 0           // -100 to +100 (local contrast)
    var dehaze: Double = 0            // -100 to +100 (remove haze)
    var texture: Double = 0           // -100 to +100 (fine detail)
    var calibration: CameraCalibration = CameraCalibration()  // Camera calibration
    
    // MARK: - Metadata & Organization
    var rating: Int = 0               // 0-5 stars
    var colorLabel: ColorLabel = .none
    var flag: Flag = .none
    var tags: [String] = []
    
    // MARK: - Explicit Memberwise Init
    /// Required because we have a custom init(from decoder:)
    init() {}
    
    /// Check if recipe has any edits
    var hasEdits: Bool {
        exposure != 0 || contrast != 0 || highlights != 0 || shadows != 0 ||
        whites != 0 || blacks != 0 || whiteBalance.hasEdits ||
        vibrance != 0 || saturation != 0 || crop.isEnabled ||
        toneCurve.hasEdits || rgbCurves.hasEdits ||
        vignette.hasEffect || splitToning.hasEffect ||
        sharpness > 0 || noiseReduction > 0 || grain.hasEffect ||
        chromaticAberration.hasEffect || perspective.hasEdits ||
        hsl.hasEdits || clarity != 0 || dehaze != 0 || texture != 0 ||
        calibration.hasEdits
    }
    
    /// Check if has any organization metadata
    var hasMetadata: Bool {
        rating > 0 || colorLabel != .none || flag != .none || !tags.isEmpty
    }
    
    /// Reset all values to defaults (preserves metadata)
    mutating func reset() {
        let savedRating = rating
        let savedColor = colorLabel
        let savedFlag = flag
        let savedTags = tags
        self = EditRecipe()
        rating = savedRating
        colorLabel = savedColor
        flag = savedFlag
        tags = savedTags
    }
    
    // MARK: - Backward Compatible Codable
    
    /// Custom decoder to handle missing keys from older sidecar versions
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Light adjustments (required in v1)
        exposure = try container.decodeIfPresent(Double.self, forKey: .exposure) ?? 0.0
        contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 0.0
        highlights = try container.decodeIfPresent(Double.self, forKey: .highlights) ?? 0.0
        shadows = try container.decodeIfPresent(Double.self, forKey: .shadows) ?? 0.0
        whites = try container.decodeIfPresent(Double.self, forKey: .whites) ?? 0.0
        blacks = try container.decodeIfPresent(Double.self, forKey: .blacks) ?? 0.0
        
        // Tone Curve
        toneCurve = try container.decodeIfPresent(ToneCurve.self, forKey: .toneCurve) ?? ToneCurve()
        
        // White Balance - NEW in v2, handle missing + migrate from old temperature/tint
        if let wb = try? container.decode(WhiteBalance.self, forKey: .whiteBalance) {
            whiteBalance = wb
        } else {
            // Try to migrate from old format using dynamic keys
            struct LegacyKeys: CodingKey {
                var stringValue: String
                var intValue: Int? { nil }
                init?(stringValue: String) { self.stringValue = stringValue }
                init?(intValue: Int) { return nil }
            }
            let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
            let oldTemp = try legacyContainer.decodeIfPresent(Double.self, forKey: LegacyKeys(stringValue: "temperature")!) ?? 0.0
            let oldTint = try legacyContainer.decodeIfPresent(Double.self, forKey: LegacyKeys(stringValue: "tint")!) ?? 0.0
            if oldTemp != 0 || oldTint != 0 {
                // Convert relative (-100..100) to absolute Kelvin
                whiteBalance = WhiteBalance(
                    preset: .custom,
                    temperature: 6500 + Int(oldTemp * 25),
                    tint: Int(oldTint)
                )
            } else {
                whiteBalance = WhiteBalance()
            }
        }
        
        // Color adjustments
        vibrance = try container.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0.0
        saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 0.0
        
        // Composition
        crop = try container.decodeIfPresent(Crop.self, forKey: .crop) ?? Crop()
        
        // Advanced Effects - NEW in v2
        rgbCurves = try container.decodeIfPresent(RGBCurves.self, forKey: .rgbCurves) ?? RGBCurves()
        vignette = try container.decodeIfPresent(Vignette.self, forKey: .vignette) ?? Vignette()
        splitToning = try container.decodeIfPresent(SplitToning.self, forKey: .splitToning) ?? SplitToning()
        sharpness = try container.decodeIfPresent(Double.self, forKey: .sharpness) ?? 0.0
        noiseReduction = try container.decodeIfPresent(Double.self, forKey: .noiseReduction) ?? 0.0
        grain = try container.decodeIfPresent(Grain.self, forKey: .grain) ?? Grain()
        
        // Lens Corrections - NEW
        chromaticAberration = try container.decodeIfPresent(ChromaticAberration.self, forKey: .chromaticAberration) ?? ChromaticAberration()
        perspective = try container.decodeIfPresent(Perspective.self, forKey: .perspective) ?? Perspective()
        
        // Professional Color Grading - NEW
        hsl = try container.decodeIfPresent(HSLAdjustment.self, forKey: .hsl) ?? HSLAdjustment()
        clarity = try container.decodeIfPresent(Double.self, forKey: .clarity) ?? 0.0
        dehaze = try container.decodeIfPresent(Double.self, forKey: .dehaze) ?? 0.0
        texture = try container.decodeIfPresent(Double.self, forKey: .texture) ?? 0.0
        calibration = try container.decodeIfPresent(CameraCalibration.self, forKey: .calibration) ?? CameraCalibration()
        
        // Metadata
        rating = try container.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        colorLabel = try container.decodeIfPresent(ColorLabel.self, forKey: .colorLabel) ?? .none
        flag = try container.decodeIfPresent(Flag.self, forKey: .flag) ?? .none
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        
        // Also try to decode using legacy keys (temperature/tint) if whiteBalance wasn't found
        // This is done above already using LegacyKeys
    }
    
    // Keys for current schema (encoding)
    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, highlights, shadows, whites, blacks
        case toneCurve, whiteBalance
        case vibrance, saturation
        case crop
        case rgbCurves, vignette, splitToning, sharpness, noiseReduction, grain
        case chromaticAberration, perspective
        case hsl, clarity, dehaze, texture, calibration
        case rating, colorLabel, flag, tags
    }
}

/// Color label for organization
enum ColorLabel: String, Codable, CaseIterable {
    case none = "none"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
    
    var color: (r: Double, g: Double, b: Double) {
        switch self {
        case .none: return (0.5, 0.5, 0.5)
        case .red: return (1.0, 0.3, 0.3)
        case .orange: return (1.0, 0.6, 0.2)
        case .yellow: return (1.0, 0.9, 0.2)
        case .green: return (0.3, 0.8, 0.3)
        case .blue: return (0.3, 0.6, 1.0)
        case .purple: return (0.7, 0.4, 1.0)
        }
    }
}

/// Flag status
enum Flag: String, Codable, CaseIterable {
    case none = "none"
    case pick = "pick"      // Keep
    case reject = "reject"  // Delete
    
    var displayName: String {
        switch self {
        case .none: return "Unflagged"
        case .pick: return "Pick"
        case .reject: return "Reject"
        }
    }
}

/// Crop settings
struct Crop: Codable, Equatable {
    var isEnabled: Bool = false
    var aspect: Aspect = .free
    var rect: CropRect = CropRect()
    var rotationDegrees: Int = 0
    
    enum Aspect: String, Codable, CaseIterable, Identifiable {
        case free = "free"
        case square = "1:1"
        case ratio4x3 = "4:3"
        case ratio3x2 = "3:2"
        case ratio16x9 = "16:9"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .free: return "Free"
            case .square: return "1:1"
            case .ratio4x3: return "4:3"
            case .ratio3x2: return "3:2"
            case .ratio16x9: return "16:9"
            }
        }
    }
}

/// Normalized crop rectangle (0-1 range)
struct CropRect: Codable, Equatable {
    var x: Double = 0.0
    var y: Double = 0.0
    var w: Double = 1.0
    var h: Double = 1.0
}

// MARK: - HSL Adjustment

/// Per-color HSL adjustment (8 channels)
struct HSLAdjustment: Codable, Equatable {
    var red: HSLChannel = HSLChannel()
    var orange: HSLChannel = HSLChannel()
    var yellow: HSLChannel = HSLChannel()
    var green: HSLChannel = HSLChannel()
    var cyan: HSLChannel = HSLChannel()
    var blue: HSLChannel = HSLChannel()
    var purple: HSLChannel = HSLChannel()
    var magenta: HSLChannel = HSLChannel()
    
    /// Check if any channel has edits
    var hasEdits: Bool {
        red.hasEdits || orange.hasEdits || yellow.hasEdits || green.hasEdits ||
        cyan.hasEdits || blue.hasEdits || purple.hasEdits || magenta.hasEdits
    }
    
    /// Get all channels as array for iteration
    var allChannels: [(name: String, channel: HSLChannel, hueCenter: Double)] {
        [
            ("Red", red, 0),
            ("Orange", orange, 30),
            ("Yellow", yellow, 60),
            ("Green", green, 120),
            ("Cyan", cyan, 180),
            ("Blue", blue, 240),
            ("Purple", purple, 270),
            ("Magenta", magenta, 300)
        ]
    }
}

/// Single HSL channel adjustment
struct HSLChannel: Codable, Equatable {
    var hue: Double = 0        // -100 to +100 (shifts hue)
    var saturation: Double = 0 // -100 to +100
    var luminance: Double = 0  // -100 to +100
    
    var hasEdits: Bool {
        hue != 0 || saturation != 0 || luminance != 0
    }
}

// MARK: - RGB Curves

/// RGB curves for per-channel adjustment
struct RGBCurves: Codable, Equatable {
    var master: [CurvePoint] = RGBCurves.defaultCurve()
    var red: [CurvePoint] = RGBCurves.defaultCurve()
    var green: [CurvePoint] = RGBCurves.defaultCurve()
    var blue: [CurvePoint] = RGBCurves.defaultCurve()
    
    /// Default 5-point linear curve
    static func defaultCurve() -> [CurvePoint] {
        [
            .init(x: 0, y: 0),
            .init(x: 0.25, y: 0.25),
            .init(x: 0.5, y: 0.5),
            .init(x: 0.75, y: 0.75),
            .init(x: 1, y: 1)
        ]
    }
    
    var hasEdits: Bool {
        !isLinear(master) || !isLinear(red) || !isLinear(green) || !isLinear(blue)
    }
    
    /// Check if curve is linear (identity)
    private func isLinear(_ points: [CurvePoint]) -> Bool {
        for point in points {
            if abs(point.x - point.y) > 0.01 {
                return false
            }
        }
        return true
    }
}

/// Curve control point (with stable UUID for drag operations)
struct CurvePoint: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var x: Double  // 0-1 input
    var y: Double  // 0-1 output
    
    init(id: UUID = UUID(), x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
    
    static func == (lhs: CurvePoint, rhs: CurvePoint) -> Bool {
        lhs.id == rhs.id && abs(lhs.x - rhs.x) < 0.001 && abs(lhs.y - rhs.y) < 0.001
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Vignette

/// Vignette effect settings
struct Vignette: Codable, Equatable {
    var amount: Double = 0       // -100..100 (negative = darken, positive = lighten)
    var midpoint: Double = 50    // 0-100, where effect starts
    var feather: Double = 50     // 0-100, softness
    
    var hasEffect: Bool { amount != 0 }
}

// MARK: - Split Toning

/// Split toning for highlight/shadow color grading
struct SplitToning: Codable, Equatable {
    var highlightHue: Double = 0        // 0-360
    var highlightSaturation: Double = 0 // 0-100
    var shadowHue: Double = 0           // 0-360
    var shadowSaturation: Double = 0    // 0-100
    var balance: Double = 0             // -100..100
    
    var hasEffect: Bool {
        highlightSaturation > 0 || shadowSaturation > 0
    }
}

// MARK: - White Balance

/// White balance settings with presets and Kelvin temperature
struct WhiteBalance: Codable, Equatable {
    var preset: WBPreset = .asShot
    var temperature: Int = 6500    // 2000-12000K
    var tint: Int = 0              // -150 to +150 (green-magenta)
    
    var hasEdits: Bool {
        preset != .asShot || temperature != 6500 || tint != 0
    }
    
    /// Apply a preset (updates temperature)
    mutating func applyPreset(_ preset: WBPreset) {
        self.preset = preset
        self.temperature = preset.kelvin
        if preset != .custom {
            self.tint = 0
        }
    }
}

/// White balance presets with corresponding Kelvin values
enum WBPreset: String, Codable, CaseIterable, Identifiable {
    case asShot = "asShot"
    case auto = "auto"
    case daylight = "daylight"
    case cloudy = "cloudy"
    case shade = "shade"
    case tungsten = "tungsten"
    case fluorescent = "fluorescent"
    case flash = "flash"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .asShot: return "As Shot"
        case .auto: return "Auto"
        case .daylight: return "Daylight"
        case .cloudy: return "Cloudy"
        case .shade: return "Shade"
        case .tungsten: return "Tungsten"
        case .fluorescent: return "Fluorescent"
        case .flash: return "Flash"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .asShot: return "camera"
        case .auto: return "wand.and.stars"
        case .daylight: return "sun.max"
        case .cloudy: return "cloud"
        case .shade: return "building.2"
        case .tungsten: return "lightbulb"
        case .fluorescent: return "light.recessed"
        case .flash: return "bolt"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    var kelvin: Int {
        switch self {
        case .asShot: return 6500
        case .auto: return 6500
        case .daylight: return 5500
        case .cloudy: return 6500
        case .shade: return 7500
        case .tungsten: return 3200
        case .fluorescent: return 4000
        case .flash: return 5500
        case .custom: return 6500
        }
    }
}

// MARK - Snapshots

/// a named point-in-time version of a recipe
struct RecipeSnapshot: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var recipe: EditRecipe
    var createdAt: Date = Date()
}

// MARK: - Sidecar JSON Structure

/// Complete sidecar file structure
struct SidecarFile: Codable {
    var schemaVersion: Int = 3 // v3: Added AI edits support
    var asset: AssetInfo
    var edit: EditRecipe
    var snapshots: [RecipeSnapshot] = []
    var aiEdits: [AIEdit] = []  // AI editing history (v3)
    var updatedAt: TimeInterval
    
    struct AssetInfo: Codable {
        var originalFilename: String
        var fileSize: Int64
        var modifiedTime: TimeInterval
    }
    
    init(for url: URL, recipe: EditRecipe) {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        self.asset = AssetInfo(
            originalFilename: url.lastPathComponent,
            fileSize: attrs?[.size] as? Int64 ?? 0,
            modifiedTime: (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        )
        self.edit = recipe
        self.snapshots = []
        self.aiEdits = []
        self.updatedAt = Date().timeIntervalSince1970
    }
    
    // MARK: - Backward Compatible Decoder
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        asset = try container.decode(AssetInfo.self, forKey: .asset)
        edit = try container.decode(EditRecipe.self, forKey: .edit)
        snapshots = try container.decodeIfPresent([RecipeSnapshot].self, forKey: .snapshots) ?? []
        aiEdits = try container.decodeIfPresent([AIEdit].self, forKey: .aiEdits) ?? []  // v3
        updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)
    }
    
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, asset, edit, snapshots, aiEdits, updatedAt
    }
}

// MARK: - Grain Effect

/// Film grain simulation
struct Grain: Codable, Equatable {
    var amount: Double = 0      // 0-100
    var size: Double = 25       // 0-100 (default 25)
    var roughness: Double = 50  // 0-100 (default 50)
    
    var hasEffect: Bool { amount > 0 }
}

// MARK: - Chromatic Aberration

/// Chromatic aberration correction
struct ChromaticAberration: Codable, Equatable {
    var amount: Double = 0  // 0-100 (auto-fix strength)
    
    var hasEffect: Bool { amount > 0 }
}

// MARK: - Perspective Correction

/// Perspective transform settings
struct Perspective: Codable, Equatable {
    var vertical: Double = 0      // -100 to +100 (keystone)
    var horizontal: Double = 0    // -100 to +100
    var rotate: Double = 0        // -45 to +45 degrees (fine rotation)
    var scale: Double = 100       // 50-150 (zoom to fill)
    
    var hasEdits: Bool {
        vertical != 0 || horizontal != 0 || rotate != 0 || scale != 100
    }
}

// MARK: - Camera Calibration

/// Camera color calibration (like Lightroom's Calibration panel)
struct CameraCalibration: Codable, Equatable {
    var shadowTint: Double = 0      // -100 to +100 (green-magenta in shadows)
    var redHue: Double = 0          // -100 to +100
    var redSaturation: Double = 0   // -100 to +100
    var greenHue: Double = 0
    var greenSaturation: Double = 0
    var blueHue: Double = 0
    var blueSaturation: Double = 0
    
    var hasEdits: Bool {
        shadowTint != 0 || redHue != 0 || redSaturation != 0 ||
        greenHue != 0 || greenSaturation != 0 || blueHue != 0 || blueSaturation != 0
    }
}
