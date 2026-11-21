import Foundation
import CoreGraphics
import ImageIO
import AppKit
import Vision
import PDFKit
import UniformTypeIdentifiers

public final class ImageConverter {
    public static func convert(
        sourceURL: URL,
        targetType: OutputFormatType,
        customQuality: Float = 0.90
    ) throws -> URL? {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "FileWheel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read image data"])
        }

        // 1. Handle "Copy to Clipboard" without creating disk clutter
        if targetType == .clipboard {
            let bitmapRep = NSBitmapImageRep(cgImage: image)
            if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(pngData, forType: .png)
                print("[ImageConverter] Copied image directly to clipboard!")
            }
            return nil
        }

        // 2. Handle OCR Text Extraction from Image
        if targetType == .extractText {
            return try extractTextFromImage(cgImage: image, sourceURL: sourceURL)
        }

        // 3. Handle WebP (macOS CGImageDestination does not natively encode WebP; use Pillow / Python3 or cwebp)
        if targetType == .webp {
            let destinationURL = makeUniqueOutputURL(for: sourceURL, newExtension: "webp")
            if encodeWebP(sourceURL: sourceURL, cgImage: image, destinationURL: destinationURL, quality: customQuality) {
                print("[ImageConverter] Successfully converted \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent)")
                return destinationURL
            } else {
                throw NSError(domain: "FileWheel", code: 2, userInfo: [NSLocalizedDescriptionKey: "WebP encoder unavailable"])
            }
        }

        // 4. Handle PDF output from Image using PDFKit so page bounds match image dimensions cleanly
        if targetType == .pdf {
            let destinationURL = makeUniqueOutputURL(for: sourceURL, newExtension: "pdf")
            let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            let pdfDoc = PDFDocument()
            if let page = PDFPage(image: nsImage) {
                pdfDoc.insert(page, at: 0)
                if pdfDoc.write(to: destinationURL) {
                    print("[ImageConverter] Successfully converted \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent)")
                    return destinationURL
                }
            }
        }

        // 5. Standard CGImageDestination formats (PNG, JPG)
        let utType: UTType
        let fileExt: String

        switch targetType {
        case .png:
            utType = .png
            fileExt = "png"
        case .jpg:
            utType = .jpeg
            fileExt = "jpg"
        default:
            utType = .png
            fileExt = "png"
        }

        let destinationURL = makeUniqueOutputURL(for: sourceURL, newExtension: fileExt)

        guard let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            utType.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "FileWheel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unsupported destination type: \(utType.identifier)"])
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: customQuality
        ]

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "FileWheel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize and write image"])
        }

        print("[ImageConverter] Successfully converted \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent)")
        return destinationURL
    }

    /// Extracts text from an image using Apple Vision VNRecognizeTextRequest, copies to clipboard, and writes a .txt file
    public static func extractTextFromImage(cgImage: CGImage, sourceURL: URL) throws -> URL {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let fullText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !fullText.isEmpty else {
            throw NSError(domain: "FileWheel", code: 4, userInfo: [NSLocalizedDescriptionKey: "No readable text found in image"])
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)

        let targetDir = makeUniqueOutputURL(for: sourceURL, newExtension: "tmp").deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outURL = makeUniqueOutputURL(
            for: targetDir.appendingPathComponent("\(baseName)_text.txt"),
            newExtension: "txt"
        )
        try fullText.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    /// Encodes WebP via Python3 Pillow or cwebp CLI
    private static func encodeWebP(sourceURL: URL, cgImage: CGImage, destinationURL: URL, quality: Float) -> Bool {
        let qInt = max(10, min(100, Int(round(quality * 100))))

        // Write a temporary PNG first in case source is HEIC
        let tempPNG = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fw_webp_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempPNG) }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]),
              (try? pngData.write(to: tempPNG)) != nil else {
            return false
        }

        let pyCandidates = [
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        for py in pyCandidates where FileManager.default.fileExists(atPath: py) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            proc.arguments = [
                "-c",
                "import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2], 'WEBP', quality=int(sys.argv[3]))",
                tempPNG.path,
                destinationURL.path,
                "\(qInt)"
            ]
            try? proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationURL.path) {
                return true
            }
        }
        return false
    }

    /// Generates unique destination path. If source is in a temp folder or read-only, routes to Desktop!
    public static func makeUniqueOutputURL(for sourceURL: URL, newExtension: String) -> URL {
        var directory = sourceURL.deletingLastPathComponent()

        let path = sourceURL.path
        let isTemp = path.contains("/var/folders/") || path.contains("/tmp/") || path.contains("/private/var/")
        let isWritable = FileManager.default.isWritableFile(atPath: directory.path)

        if isTemp || !isWritable {
            if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                directory = desktop
            }
        }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        var candidate = directory.appendingPathComponent("\(baseName).\(newExtension)")
        var counter = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) (\(counter)).\(newExtension)")
            counter += 1
        }

        return candidate
    }
}
