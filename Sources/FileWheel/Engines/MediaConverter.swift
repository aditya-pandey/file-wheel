import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import AppKit

public final class MediaConverter {
    /// Extracts audio track from video file and saves as high-quality M4A
    public static func extractAudio(sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        let outputURL = ImageConverter.makeUniqueOutputURL(for: sourceURL, newExtension: "m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(NSError(domain: "MediaConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    print("[MediaConverter] Audio extracted -> \(outputURL.lastPathComponent)")
                    completion(.success(outputURL))
                case .failed, .cancelled:
                    let err = exportSession.error ?? NSError(domain: "MediaConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
                    completion(.failure(err))
                default:
                    break
                }
            }
        }
    }

    /// Converts video to animated looping GIF using native AVAssetImageGenerator and ImageIO
    public static func convertToGIF(
        sourceURL: URL,
        targetFPS: Int = 12,
        maxWidth: CGFloat = 480,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: sourceURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero

            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard durationSeconds > 0 else {
                completion(.failure(NSError(domain: "MediaConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Video duration is zero"])))
                return
            }

            // Cap animation duration at 12 seconds for responsive GIF size
            let effectiveDuration = min(durationSeconds, 12.0)
            let frameCount = max(2, Int(effectiveDuration * Double(targetFPS)))
            let frameInterval = effectiveDuration / Double(frameCount)

            let outputURL = ImageConverter.makeUniqueOutputURL(for: sourceURL, newExtension: "gif")
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                "com.compuserve.gif" as CFString,
                frameCount,
                nil
            ) else {
                completion(.failure(NSError(domain: "MediaConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create GIF destination"])))
                return
            }

            let gifProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFLoopCount: 0 // Infinite loop
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frameInterval
                ]
            ]

            var addedCount = 0
            for i in 0..<frameCount {
                let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: 600)
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    let scaledImage = resizeCGImage(cgImage, maxWidth: maxWidth) ?? cgImage
                    CGImageDestinationAddImage(destination, scaledImage, frameProperties as CFDictionary)
                    addedCount += 1
                }
            }

            guard addedCount > 0, CGImageDestinationFinalize(destination) else {
                completion(.failure(NSError(domain: "MediaConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize GIF"])))
                return
            }

            // Copy GIF to clipboard
            if let gifData = try? Data(contentsOf: outputURL) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(gifData, forType: .init("com.compuserve.gif"))
            }

            print("[MediaConverter] GIF created with \(addedCount) frames -> \(outputURL.lastPathComponent)")
            completion(.success(outputURL))
        }
    }

    private static func resizeCGImage(_ image: CGImage, maxWidth: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > maxWidth else { return image }

        let scale = maxWidth / width
        let targetSize = CGSize(width: maxWidth, height: height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return ctx.makeImage()
    }
}
