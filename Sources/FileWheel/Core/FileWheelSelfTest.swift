import Foundation
import AppKit
import PDFKit

public enum FileWheelSelfTest {
    private static var passed = 0
    private static var failed = 0

    private static func expect(_ condition: Bool, _ message: String) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("❌ FAIL: \(message)")
        }
    }

    public static func runAll() -> Bool {
        passed = 0
        failed = 0
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 Running FileWheel Automated QA & End-to-End Engine Suite...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        testDonutGeometry()
        testFormatResolver()
        testImageConversionsAndOCR()
        testPDFConverterEngine()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if failed == 0 {
            print("✅ ALL \(passed) FILEWHEEL TESTS PASSED (0 failures)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return true
        } else {
            print("❌ \(failed) TESTS FAILED (\(passed) passed)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return false
        }
    }

    private static func testDonutGeometry() {
        print("▸ Testing DonutGeometry (Compass Slices & Dead Zone)...")
        let (_, deadSlice) = DonutGeometry.evaluate(dx: 10, dy: 10, sliceCount: 6)
        expect(deadSlice == nil, "Radius inside deadZoneRadius (65pt) returns nil")

        let (_, northSlice) = DonutGeometry.evaluate(dx: 0, dy: 120, sliceCount: 6)
        expect(northSlice == 0, "North (dx=0, dy=120) maps to slice 0")

        let (_, southSlice) = DonutGeometry.evaluate(dx: 0, dy: -120, sliceCount: 6)
        expect(southSlice == 3, "South (dx=0, dy=-120) maps to slice 3 of 6")

        let (_, east3Slice) = DonutGeometry.evaluate(dx: 120, dy: -60, sliceCount: 3)
        expect(east3Slice == 1, "SE in 3-slice wheel maps to slice 1")
    }

    private static func testFormatResolver() {
        print("▸ Testing FormatResolver (Image, PDF, Video Target Resolution)...")
        let pngTargets = FormatResolver.resolveTargets(for: URL(fileURLWithPath: "/tmp/sample.png"))
        expect(pngTargets.contains(where: { $0.type == .webp }), "PNG offers WebP target")
        expect(pngTargets.contains(where: { $0.type == .cutoutPNG }), "PNG offers AI Cutout target")
        expect(pngTargets.contains(where: { $0.type == .jpg }), "PNG offers JPG target")
        expect(pngTargets.contains(where: { $0.type == .pdf }), "PNG offers PDF target")
        expect(pngTargets.contains(where: { $0.type == .extractText }), "PNG offers OCR Text target")
        expect(!pngTargets.contains(where: { $0.type == .png }), "PNG does not redundantly offer PNG")

        let pdfTargets = FormatResolver.resolveTargets(for: URL(fileURLWithPath: "/tmp/report.pdf"))
        expect(pdfTargets.count == 3, "PDF resolves to 3 specialized slices")
        expect(pdfTargets.contains(where: { $0.type == .pngPages }), "PDF offers Render Pages to PNGs")
        expect(pdfTargets.contains(where: { $0.type == .extractText }), "PDF offers OCR/Text Extraction")
        expect(pdfTargets.contains(where: { $0.type == .clipboard }), "PDF offers Copy First Page")

        let mp4Targets = FormatResolver.resolveTargets(for: URL(fileURLWithPath: "/tmp/clip.mp4"))
        expect(mp4Targets.contains(where: { $0.type == .audioExtract }), "MP4 offers Audio M4A extraction")
        expect(mp4Targets.contains(where: { $0.type == .gif }), "MP4 offers Animated GIF conversion")
    }

    private static func testImageConversionsAndOCR() {
        print("▸ Testing ImageConverter (JPG, WebP, PDF, Clipboard, Vision OCR)...")
        let qaDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/weapon_wheel/file_wheel/.qa_temp_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: qaDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qaDir) }

        // Render a synthetic 400x200 image with clear text for OCR & conversion testing
        let srcPNG = qaDir.appendingPathComponent("test_card.png")
        let size = NSSize(width: 480, height: 200)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 42),
            .foregroundColor: NSColor.black
        ]
        ("FILEWHEEL QA 2026" as NSString).draw(at: NSPoint(x: 36, y: 74), withAttributes: attrs)
        img.unlockFocus()

        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: srcPNG)
        }
        expect(FileManager.default.fileExists(atPath: srcPNG.path), "Created synthetic test PNG")

        // 1. Convert PNG -> JPG
        if let jpgURL = try? ImageConverter.convert(sourceURL: srcPNG, targetType: .jpg, customQuality: 0.85) {
            expect(FileManager.default.fileExists(atPath: jpgURL.path), "Converted PNG -> JPG")
        } else {
            expect(false, "PNG -> JPG conversion threw error")
        }

        // 2. Convert PNG -> WebP
        if let webpURL = try? ImageConverter.convert(sourceURL: srcPNG, targetType: .webp, customQuality: 0.85) {
            expect(FileManager.default.fileExists(atPath: webpURL.path), "Converted PNG -> WebP")
        } else {
            expect(false, "PNG -> WebP conversion threw error")
        }

        // 3. Convert PNG -> PDF
        if let pdfURL = try? ImageConverter.convert(sourceURL: srcPNG, targetType: .pdf) {
            expect(FileManager.default.fileExists(atPath: pdfURL.path), "Converted PNG -> PDF")
            let doc = PDFDocument(url: pdfURL)
            expect(doc?.pageCount == 1, "Generated PDF has 1 valid page")
        } else {
            expect(false, "PNG -> PDF conversion threw error")
        }

        // 4. Extract OCR Text from PNG
        if let txtURL = try? ImageConverter.convert(sourceURL: srcPNG, targetType: .extractText),
           let content = try? String(contentsOf: txtURL, encoding: .utf8) {
            expect(content.uppercased().contains("FILEWHEEL"), "Vision OCR extracted 'FILEWHEEL' from image")
        } else {
            expect(false, "Vision OCR on image failed")
        }
    }

    private static func testPDFConverterEngine() {
        print("▸ Testing PDFConverterEngine (Multi-Page PNG Render, Text Extraction, Clipboard)...")
        let qaDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/weapon_wheel/file_wheel/.qa_pdf_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: qaDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: qaDir) }

        let pdfURL = qaDir.appendingPathComponent("multi_test.pdf")
        let pdfDoc = PDFDocument()

        for pageNum in 1...2 {
            let pageSize = NSSize(width: 400, height: 300)
            let pageImg = NSImage(size: pageSize)
            pageImg.lockFocus()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(origin: .zero, size: pageSize)).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 36),
                .foregroundColor: NSColor.black
            ]
            ("PDF ENGINE PAGE \(pageNum)" as NSString).draw(at: NSPoint(x: 30, y: 120), withAttributes: attrs)
            pageImg.unlockFocus()
            if let pdfPage = PDFPage(image: pageImg) {
                pdfDoc.insert(pdfPage, at: pdfDoc.pageCount)
            }
        }
        pdfDoc.write(to: pdfURL)
        expect(FileManager.default.fileExists(atPath: pdfURL.path), "Created 2-page test PDF")

        // 1. Render 2-page PDF to PNG folder
        if let pagesFolder = try? PDFConverterEngine.renderPagesToPNG(sourceURL: pdfURL) {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: pagesFolder.path)) ?? []
            expect(items.count == 2, "Rendered 2-page PDF into 2 PNG files inside _pages folder")
        } else {
            expect(false, "PDFConverterEngine.renderPagesToPNG failed")
        }

        // 2. Extract text (via Vision OCR fallback since PDFPage(image:) has no digital text layer!)
        if let txtURL = try? PDFConverterEngine.extractText(sourceURL: pdfURL),
           let extracted = try? String(contentsOf: txtURL, encoding: .utf8) {
            expect(extracted.uppercased().contains("ENGINE"), "PDFConverterEngine.extractText OCR fallback succeeded")
        } else {
            expect(false, "PDFConverterEngine.extractText failed")
        }

        // 3. Copy first page to clipboard
        let copyOK = (try? PDFConverterEngine.copyFirstPage(sourceURL: pdfURL)) != nil
        expect(copyOK, "PDFConverterEngine.copyFirstPage succeeded")
    }
}
