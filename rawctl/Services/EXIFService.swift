//
//  EXIFService.swift
//  rawctl
//
//  Service for extracting complete EXIF metadata from image files
//

import Foundation
import ImageIO
import CoreLocation

/// Complete EXIF data structure with all metadata fields
struct EXIFData: Hashable, Codable {
    // MARK: - Camera Info
    var cameraMake: String?
    var cameraModel: String?
    var lens: String?
    var lensModel: String?
    var serialNumber: String?
    var software: String?
    
    // MARK: - Exposure Settings
    var iso: Int?
    var aperture: Double?           // f/2.8 -> 2.8
    var shutterSpeed: Double?       // 1/200 -> 0.005
    var exposureCompensation: Double?
    var focalLength: Double?        // 50mm -> 50
    var focalLength35mm: Int?
    var exposureMode: String?
    var meteringMode: String?
    var whiteBalance: String?
    var flash: String?
    
    // MARK: - Date/Time
    var dateTimeOriginal: Date?
    var dateTimeDigitized: Date?
    
    // MARK: - GPS
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var gpsAltitude: Double?
    
    // MARK: - Image Info
    var width: Int?
    var height: Int?
    var colorSpace: String?
    var bitDepth: Int?
    var orientation: Int?
    
    // MARK: - Copyright
    var copyright: String?
    var artist: String?
    
    // MARK: - Computed Properties
    
    var apertureString: String? {
        guard let f = aperture else { return nil }
        return String(format: "f/%.1f", f)
    }
    
    var shutterSpeedString: String? {
        guard let s = shutterSpeed else { return nil }
        if s >= 1 {
            return String(format: "%.1fs", s)
        } else {
            let denominator = Int(1.0 / s)
            return "1/\(denominator)s"
        }
    }
    
    var isoString: String? {
        guard let iso = iso else { return nil }
        return "ISO \(iso)"
    }
    
    var focalLengthString: String? {
        guard let fl = focalLength else { return nil }
        if let fl35 = focalLength35mm, fl35 != Int(fl) {
            return String(format: "%.0fmm (%.0fmm equiv)", fl, Double(fl35))
        }
        return String(format: "%.0fmm", fl)
    }
    
    var dimensionsString: String? {
        guard let w = width, let h = height else { return nil }
        return "\(w) × \(h)"
    }
    
    var megapixels: Double? {
        guard let w = width, let h = height else { return nil }
        return Double(w * h) / 1_000_000
    }
    
    var hasGPS: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }
    
    var gpsCoordinateString: String? {
        guard let lat = gpsLatitude, let lon = gpsLongitude else { return nil }
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        return String(format: "%.4f° %@, %.4f° %@", abs(lat), latDir, abs(lon), lonDir)
    }
}

/// Service for extracting EXIF metadata from images
actor EXIFService {
    static let shared = EXIFService()
    
    // Cache for extracted EXIF data
    private var cache: [String: EXIFData] = [:]
    
    /// Extract EXIF data from an image file
    func extractEXIF(from url: URL) async -> EXIFData? {
        // Check cache
        let cacheKey = url.path
        if let cached = cache[cacheKey] {
            return cached
        }
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var exif = EXIFData()
        
        // Extract TIFF data
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            exif.cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            exif.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            exif.software = tiff[kCGImagePropertyTIFFSoftware as String] as? String
            exif.artist = tiff[kCGImagePropertyTIFFArtist as String] as? String
            exif.copyright = tiff[kCGImagePropertyTIFFCopyright as String] as? String
            exif.orientation = tiff[kCGImagePropertyTIFFOrientation as String] as? Int
        }
        
        // Extract EXIF data
        if let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // ISO
            if let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
               let iso = isoArray.first {
                exif.iso = iso
            }
            
            // Aperture (FNumber)
            if let fNumber = exifDict[kCGImagePropertyExifFNumber as String] as? Double {
                exif.aperture = fNumber
            }
            
            // Shutter Speed
            if let exposureTime = exifDict[kCGImagePropertyExifExposureTime as String] as? Double {
                exif.shutterSpeed = exposureTime
            }
            
            // Exposure Compensation
            if let expComp = exifDict[kCGImagePropertyExifExposureBiasValue as String] as? Double {
                exif.exposureCompensation = expComp
            }
            
            // Focal Length
            if let fl = exifDict[kCGImagePropertyExifFocalLength as String] as? Double {
                exif.focalLength = fl
            }
            
            // Focal Length 35mm
            if let fl35 = exifDict[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Int {
                exif.focalLength35mm = fl35
            }
            
            // Lens
            if let lens = exifDict[kCGImagePropertyExifLensModel as String] as? String {
                exif.lensModel = lens
                exif.lens = lens
            }
            
            // Date/Time
            if let dateStr = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                exif.dateTimeOriginal = parseEXIFDate(dateStr)
            }
            if let dateStr = exifDict[kCGImagePropertyExifDateTimeDigitized as String] as? String {
                exif.dateTimeDigitized = parseEXIFDate(dateStr)
            }
            
            // Exposure Mode
            if let mode = exifDict[kCGImagePropertyExifExposureMode as String] as? Int {
                exif.exposureMode = exposureModeString(mode)
            }
            
            // Metering Mode
            if let metering = exifDict[kCGImagePropertyExifMeteringMode as String] as? Int {
                exif.meteringMode = meteringModeString(metering)
            }
            
            // White Balance
            if let wb = exifDict[kCGImagePropertyExifWhiteBalance as String] as? Int {
                exif.whiteBalance = wb == 0 ? "Auto" : "Manual"
            }
            
            // Flash
            if let flash = exifDict[kCGImagePropertyExifFlash as String] as? Int {
                exif.flash = flashString(flash)
            }
            
            // Color Space
            if let cs = exifDict[kCGImagePropertyExifColorSpace as String] as? Int {
                exif.colorSpace = colorSpaceString(cs)
            }
            
            // Pixel Dimensions
            if let w = exifDict[kCGImagePropertyExifPixelXDimension as String] as? Int {
                exif.width = w
            }
            if let h = exifDict[kCGImagePropertyExifPixelYDimension as String] as? Int {
                exif.height = h
            }
        }
        
        // Extract GPS data
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
                exif.gpsLatitude = latRef == "S" ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                exif.gpsLongitude = lonRef == "W" ? -lon : lon
            }
            if let alt = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                exif.gpsAltitude = alt
            }
        }
        
        // Fallback dimensions from image properties
        if exif.width == nil {
            exif.width = properties[kCGImagePropertyPixelWidth as String] as? Int
        }
        if exif.height == nil {
            exif.height = properties[kCGImagePropertyPixelHeight as String] as? Int
        }
        
        // Bit depth
        exif.bitDepth = properties[kCGImagePropertyDepth as String] as? Int
        
        // Cache and return
        cache[cacheKey] = exif
        return exif
    }
    
    /// Clear the cache
    func clearCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func parseEXIFDate(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: str)
    }
    
    private func exposureModeString(_ mode: Int) -> String {
        switch mode {
        case 0: return "Auto"
        case 1: return "Manual"
        case 2: return "Auto Bracket"
        default: return "Unknown"
        }
    }
    
    private func meteringModeString(_ mode: Int) -> String {
        switch mode {
        case 1: return "Average"
        case 2: return "Center-Weighted"
        case 3: return "Spot"
        case 4: return "Multi-Spot"
        case 5: return "Pattern"
        case 6: return "Partial"
        default: return "Unknown"
        }
    }
    
    private func flashString(_ flash: Int) -> String {
        if flash & 1 == 0 {
            return "No Flash"
        } else {
            return "Flash Fired"
        }
    }
    
    private func colorSpaceString(_ cs: Int) -> String {
        switch cs {
        case 1: return "sRGB"
        case 2: return "Adobe RGB"
        case 0xFFFF: return "Uncalibrated"
        default: return "Unknown"
        }
    }
}
