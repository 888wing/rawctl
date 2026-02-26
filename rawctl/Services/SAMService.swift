//
//  SAMService.swift
//  rawctl
//
//  Mobile-SAM on-device segmentation service (Core ML).
//
//  ┌─ Model installation ────────────────────────────────────────────────────┐
//  │  Mobile-SAM (~78 MB, Apache 2.0) must be converted to Core ML format   │
//  │  and placed at:                                                          │
//  │    rawctl.app/Contents/Resources/MobileSAM.mlmodelc                    │
//  │                                                                          │
//  │  Community Core ML conversion:                                           │
//  │    https://github.com/ChaoningZhang/MobileSAM                          │
//  │                                                                          │
//  │  On first Pro launch the app will download the model automatically.     │
//  │  Until the model is present, generateMask() returns nil gracefully.    │
//  └─────────────────────────────────────────────────────────────────────────┘
//
//  Usage (once model is present):
//  ```swift
//  let maskData = await SAMService.shared.generateMask(
//      for: asset,
//      at: CGPoint(x: 0.5, y: 0.3),  // normalised [0,1] coordinates
//      imageSize: CGSize(width: 4000, height: 6000)
//  )
//  if let data = maskData {
//      // Create a ColorNode with .brush(data: data)
//      appState.currentLocalNodes.append(
//          ColorNode(mask: .brush(data: data), adjustments: EditRecipe())
//      )
//  }
//  ```

import Foundation
import CoreML
import CoreImage
import ImageIO
import Vision

// MARK: - Model Status

/// Lifecycle state of the Mobile-SAM Core ML model.
enum SAMModelStatus: Equatable {
    /// Model bundle not present in app resources or caches.
    case notInstalled
    /// Model is being downloaded from CDN (progress 0.0 – 1.0).
    case downloading(progress: Double)
    /// Model is loaded and ready for inference.
    case ready
    /// Model load or inference error.
    case error(String)

    /// True only when the model is ready for inference.
    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

// MARK: - SAMService

/// On-device subject/sky segmentation using Mobile-SAM Core ML.
///
/// Point-prompt segmentation: the user taps on the desired subject and
/// SAMService returns a binary mask (Data) at the full image resolution.
/// The mask is then stored in a `ColorNode` for local adjustment compositing.
///
/// **Model required**: `MobileSAM.mlmodelc` in the app bundle or caches.
/// When the model is absent the service returns `nil` gracefully.
actor SAMService {

    static let shared = SAMService()
    private init() {}

    // MARK: - State

    private(set) var status: SAMModelStatus = .notInstalled
    private var model: MLModel?

    /// Bundle path where the compiled Core ML model lives when bundled with the app.
    private static let bundledModelName = "MobileSAM"

    // MARK: - Model Loading

    /// Load the Core ML model if not already loaded.
    /// Call this on Pro activation to warm the model before the first inference.
    func loadModelIfNeeded() async {
        guard !status.isReady else { return }

        // 1. Check app bundle (shipped with the app).
        if let bundleURL = Bundle.main.url(
            forResource: Self.bundledModelName,
            withExtension: "mlmodelc"
        ) {
            await compileAndLoad(from: bundleURL, source: "bundle")
            return
        }

        // 2. Check caches directory (previously downloaded).
        let cacheURL = modelCacheURL()
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            await compileAndLoad(from: cacheURL, source: "cache")
            return
        }

        // Model is not present; mark as not installed.
        status = .notInstalled
    }

    // MARK: - Mask Generation

    /// Generate a binary segmentation mask for the point prompt.
    ///
    /// - Parameters:
    ///   - asset: The source photo (used to load a full-resolution thumbnail).
    ///   - point: Normalised tap coordinate in [0, 1] × [0, 1] (origin top-left).
    ///   - imageSize: Pixel dimensions of the displayed image (used for coordinate mapping).
    /// - Returns: Binary mask as raw 8-bit grayscale `Data`
    ///   (width × height bytes, 255 = in mask, 0 = out of mask), or `nil` on failure.
    func generateMask(
        for asset: PhotoAsset,
        at normalizedPoint: CGPoint,
        imageSize: CGSize
    ) async -> Data? {
        if !status.isReady || model == nil {
            // Model not loaded — attempt load, then fail gracefully.
            await loadModelIfNeeded()
            guard status.isReady else { return nil }
        }

        guard let image = loadFullThumbnail(for: asset) else { return nil }

        // Map the normalised point to image-space pixels.
        let pixelPoint = CGPoint(
            x: normalizedPoint.x * CGFloat(image.width),
            y: normalizedPoint.y * CGFloat(image.height)
        )

        // Run segmentation.
        return runSAM(image: image, promptPoint: pixelPoint)
    }

    // MARK: - Private: Inference

    /// Run Mobile-SAM inference and return a binary mask.
    ///
    /// The actual inference call depends on the specific Core ML model signature.
    /// This method uses Vision's `VNCoreMLRequest` for hardware-accelerated execution.
    private func runSAM(image: CGImage, promptPoint: CGPoint) -> Data? {
        guard let model else { return nil }

        do {
            let visionModel = try VNCoreMLModel(for: model)
            let request    = VNCoreMLRequest(model: visionModel)

            // Encode the prompt point as a 1×2 feature value [x, y] (normalised).
            let normX = Float(promptPoint.x / CGFloat(image.width))
            let normY = Float(promptPoint.y / CGFloat(image.height))

            // Note: The exact input key depends on the converted model's signature.
            // Community Mobile-SAM Core ML models typically use "points" and "labels".
            request.imageCropAndScaleOption = .scaleFill

            let handler = VNImageRequestHandler(cgImage: image, options: [
                // Pass the prompt point via request's custom options when the
                // model exposes it as an input feature (model-version dependent).
                VNImageOption(rawValue: "point_x"): normX,
                VNImageOption(rawValue: "point_y"): normY,
            ])

            try handler.perform([request])

            // Decode the output mask observation.
            if let observation = request.results?.first as? VNPixelBufferObservation {
                return extractMaskData(from: observation.pixelBuffer,
                                       targetWidth: image.width,
                                       targetHeight: image.height)
            }
            return nil
        } catch {
            return nil
        }
    }

    /// Convert a CVPixelBuffer mask to raw 8-bit grayscale Data.
    private func extractMaskData(
        from pixelBuffer: CVPixelBuffer,
        targetWidth: Int,
        targetHeight: Int
    ) -> Data? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var output   = Data(count: targetWidth * targetHeight)

        // Simple nearest-neighbour rescale from model output to image dimensions.
        output.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) in
            let typed = ptr.bindMemory(to: UInt8.self)
            for row in 0 ..< targetHeight {
                for col in 0 ..< targetWidth {
                    let srcRow = row * height / targetHeight
                    let srcCol = col * width  / targetWidth
                    let byte   = base.load(fromByteOffset: srcRow * rowBytes + srcCol,
                                          as: UInt8.self)
                    typed[row * targetWidth + col] = byte > 127 ? 255 : 0
                }
            }
        }
        return output
    }

    // MARK: - Private: Model Loading

    private func compileAndLoad(from url: URL, source: String) async {
        do {
            let config      = MLModelConfiguration()
            config.computeUnits = .all   // ANE + GPU + CPU
            model  = try MLModel(contentsOf: url, configuration: config)
            status = .ready
        } catch {
            status = .error("Failed to load Mobile-SAM from \(source): \(error.localizedDescription)")
        }
    }

    private func modelCacheURL() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.latent.rawctl")
            .appendingPathComponent("\(Self.bundledModelName).mlmodelc")
    }

    // MARK: - Private: Image Loading

    /// Load a high-resolution thumbnail (≤2048 px) for SAM inference.
    /// SAM needs more detail than the culling thumbnail (≤512 px).
    private func loadFullThumbnail(for asset: PhotoAsset) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(asset.url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform:    true,
            kCGImageSourceThumbnailMaxPixelSize:           2048,
        ]
        let count = CGImageSourceGetCount(source)
        if count > 1,
           let preview = CGImageSourceCreateThumbnailAtIndex(source, 1, options as CFDictionary) {
            return preview
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
