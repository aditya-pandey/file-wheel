import Foundation
import CoreGraphics
import Vision
import CoreImage
import CoreVideo
import AppKit

public final class VisionCutoutEngine {
    /// Removes background using Apple Silicon on-device Neural Engine with multi-stage fallback
    public static func removeBackground(sourceURL: URL) throws -> URL {
        guard let (cgImage, orientation) = loadCGImage(from: sourceURL) else {
            throw NSError(
                domain: "VisionCutout",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not read image file"]
            )
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        var outputCGImage: CGImage?

        // ━━ Stage 1: Foreground Instance Mask Request (Objects, Pets, Products, People) ━━
        let instanceRequest = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([instanceRequest])
            if let result = instanceRequest.results?.first, !result.allInstances.isEmpty {
                let buffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let ciImage = CIImage(cvPixelBuffer: buffer)
                let ciContext = CIContext(options: nil)
                outputCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent)
                print("[VisionCutout] Stage 1 (Foreground Instance) succeeded with \(result.allInstances.count) instances")
            }
        } catch {
            print("[VisionCutout] Stage 1 (Foreground Instance) error: \(error.localizedDescription)")
        }

        // ━━ Stage 2: Person Segmentation Fallback (Portraits, Full-Body, Groups) ━━
        if outputCGImage == nil {
            print("[VisionCutout] Falling back to Stage 2 (Person Segmentation)...")
            let personRequest = VNGeneratePersonSegmentationRequest()
            personRequest.qualityLevel = .accurate
            
            do {
                try handler.perform([personRequest])
                if let personResult = personRequest.results?.first {
                    let maskBuffer = personResult.pixelBuffer
                    
                    // Verify the mask actually detected a person (not all black)
                    if isMaskPopulated(maskBuffer, threshold: 100, minPixels: 150) {
                        let maskCI = CIImage(cvPixelBuffer: maskBuffer)
                        var sourceCI = CIImage(cgImage: cgImage)
                        if orientation != .up {
                            sourceCI = sourceCI.oriented(forExifOrientation: Int32(orientation.rawValue))
                        }

                        let scaleX = sourceCI.extent.width / maskCI.extent.width
                        let scaleY = sourceCI.extent.height / maskCI.extent.height
                        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                        if let filter = CIFilter(name: "CIBlendWithMask") {
                            filter.setValue(sourceCI, forKey: kCIInputImageKey)
                            filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
                            filter.setValue(scaledMask, forKey: kCIInputMaskImageKey)
                            if let outputCI = filter.outputImage {
                                let ciContext = CIContext(options: nil)
                                outputCGImage = ciContext.createCGImage(outputCI, from: sourceCI.extent)
                                print("[VisionCutout] Stage 2 (Person Segmentation) succeeded")
                            }
                        }
                    } else {
                        print("[VisionCutout] Stage 2: Person mask empty, no subject found")
                    }
                }
            } catch {
                print("[VisionCutout] Stage 2 (Person Segmentation) error: \(error.localizedDescription)")
            }
        }

        guard let finalCGImage = outputCGImage else {
            throw NSError(
                domain: "VisionCutout",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No foreground subject detected"]
            )
        }

        // Encode to transparent PNG
        let bitmapRep = NSBitmapImageRep(cgImage: finalCGImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "VisionCutout",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode transparent PNG"]
            )
        }

        // Copy cutout directly to clipboard for instant pasting (⌘V) in any Mac app
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)
        if let tiffData = bitmapRep.tiffRepresentation {
            NSPasteboard.general.setData(tiffData, forType: .tiff)
        }
        print("[VisionCutout] Cutout copied directly to clipboard (PNG & TIFF)!")

        // Determine destination file path (redirects temp/browser drags to Desktop)
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outputURL = ImageConverter.makeUniqueOutputURL(
            for: sourceURL.deletingLastPathComponent().appendingPathComponent("\(baseName)_cutout.png"),
            newExtension: "png"
        )

        try pngData.write(to: outputURL)
        print("[VisionCutout] Successfully saved cutout to \(outputURL.path)")
        return outputURL
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────────────────────────────

    private static func loadCGImage(from url: URL) -> (CGImage, CGImagePropertyOrientation)? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: true,
            kCGImageSourceShouldAllowFloat: true
        ]

        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) {
            var orientation: CGImagePropertyOrientation = .up
            if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let rawVal = properties[kCGImagePropertyOrientation] as? UInt32 {
                orientation = CGImagePropertyOrientation(rawValue: rawVal) ?? .up
            }
            return (cgImage, orientation)
        }

        if let nsImage = NSImage(contentsOf: url),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return (cgImage, .up)
        }

        return nil
    }

    private static func isMaskPopulated(_ pixelBuffer: CVPixelBuffer, threshold: UInt8, minPixels: Int) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }

        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        var count = 0

        // Subsample rows for blazing fast check
        let step = max(1, height / 100)
        for y in stride(from: 0, to: height, by: step) {
            let rowOffset = y * bytesPerRow
            for x in stride(from: 0, to: width, by: step) {
                if ptr[rowOffset + x] >= threshold {
                    count += 1
                    if count >= minPixels {
                        return true
                    }
                }
            }
        }

        return count >= minPixels
    }
}
