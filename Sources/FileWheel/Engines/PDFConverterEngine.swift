import Foundation
import PDFKit
import CoreGraphics
import Vision
import AppKit

public final class PDFConverterEngine {
    /// Renders PDF pages to high-resolution PNGs
    /// If single page: outputs `<baseName>.png`
    /// If multi-page: creates `<baseName>_pages/` containing `<baseName>_page_1.png`, etc.
    public static func renderPagesToPNG(sourceURL: URL) throws -> URL {
        guard let doc = PDFDocument(url: sourceURL), doc.pageCount > 0 else {
            throw NSError(domain: "PDFConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or unreadable PDF document"])
        }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let targetDir = ImageConverter.makeUniqueOutputURL(for: sourceURL, newExtension: "tmp").deletingLastPathComponent()

        if doc.pageCount == 1 {
            // Single page document
            guard let page = doc.page(at: 0) else {
                throw NSError(domain: "PDFConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF page"])
            }

            let pngData = try renderPageToPNGData(page: page, scale: 2.0)
            let outURL = ImageConverter.makeUniqueOutputURL(
                for: targetDir.appendingPathComponent("\(baseName).png"),
                newExtension: "png"
            )
            try pngData.write(to: outURL)

            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(pngData, forType: .png)
            print("[PDFConverter] 1 page rendered -> \(outURL.lastPathComponent)")
            return outURL
        } else {
            // Multi-page document: create folder
            var folderURL = targetDir.appendingPathComponent("\(baseName)_pages")
            var counter = 1
            while FileManager.default.fileExists(atPath: folderURL.path) {
                folderURL = targetDir.appendingPathComponent("\(baseName)_pages (\(counter))")
                counter += 1
            }

            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            var firstPagePNG: Data?

            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    if let pageData = try? renderPageToPNGData(page: page, scale: 2.0) {
                        let pageFileName = String(format: "%@_page_%02d.png", baseName, i + 1)
                        let pageURL = folderURL.appendingPathComponent(pageFileName)
                        try? pageData.write(to: pageURL)

                        if i == 0 {
                            firstPagePNG = pageData
                        }
                    }
                }
            }

            // Copy first page to clipboard for convenience
            if let firstPNG = firstPagePNG {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setData(firstPNG, forType: .png)
            }

            print("[PDFConverter] \(doc.pageCount) pages rendered into \(folderURL.lastPathComponent)")
            return folderURL
        }
    }

    /// Extracts text from PDF using digital text layer or Vision neural OCR for scanned documents
    public static func extractText(sourceURL: URL) throws -> URL {
        guard let doc = PDFDocument(url: sourceURL), doc.pageCount > 0 else {
            throw NSError(domain: "PDFConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid or unreadable PDF document"])
        }

        var fullText = ""

        // 1. Try digital text extraction first
        if let digitalString = doc.string, digitalString.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 {
            fullText = digitalString
            print("[PDFConverter] Extracted \(fullText.count) characters of digital text")
        } else {
            // 2. Fallback to Apple Vision Neural OCR for scanned pages
            print("[PDFConverter] Digital text empty. Running Vision Neural OCR...")
            var ocrLines: [String] = []

            for i in 0..<min(doc.pageCount, 50) { // Safety cap at 50 pages for instant responsiveness
                guard let page = doc.page(at: i) else { continue }
                let rect = page.bounds(for: .mediaBox)
                let thumb = page.thumbnail(of: CGSize(width: rect.width * 2, height: rect.height * 2), for: .mediaBox)

                if let tiff = thumb.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let cgImage = rep.cgImage {
                    let req = VNRecognizeTextRequest()
                    req.recognitionLevel = .accurate
                    req.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try? handler.perform([req])

                    let pageLines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    if !pageLines.isEmpty {
                        ocrLines.append("--- Page \(i + 1) ---")
                        ocrLines.append(contentsOf: pageLines)
                    }
                }
            }

            fullText = ocrLines.joined(separator: "\n")
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "PDFConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "No text found in PDF document"])
        }

        // Copy directly to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(fullText, forType: .string)
        print("[PDFConverter] Text copied to clipboard! (\(fullText.count) chars)")

        // Save .txt file
        let targetDir = ImageConverter.makeUniqueOutputURL(for: sourceURL, newExtension: "tmp").deletingLastPathComponent()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let outURL = ImageConverter.makeUniqueOutputURL(
            for: targetDir.appendingPathComponent("\(baseName)_text.txt"),
            newExtension: "txt"
        )
        try fullText.write(to: outURL, atomically: true, encoding: .utf8)
        return outURL
    }

    /// Copies first page of PDF directly to clipboard as high-res PNG image
    public static func copyFirstPage(sourceURL: URL) throws {
        guard let doc = PDFDocument(url: sourceURL), let page = doc.page(at: 0) else {
            throw NSError(domain: "PDFConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read PDF page"])
        }

        let pngData = try renderPageToPNGData(page: page, scale: 2.0)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(pngData, forType: .png)
        print("[PDFConverter] First page copied directly to clipboard!")
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────

    private static func renderPageToPNGData(page: PDFPage, scale: CGFloat = 2.0) throws -> Data {
        let bounds = page.bounds(for: .mediaBox)
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let thumb = page.thumbnail(of: renderSize, for: .mediaBox)

        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "PDFConverter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
        }

        return png
    }
}
