import Foundation
import UniformTypeIdentifiers
import SwiftUI

public enum OutputFormatType: String, CaseIterable, Identifiable {
    case webp = "WEBP"
    case png = "PNG"
    case jpg = "JPG"
    case pdf = "PDF"
    case cutoutPNG = "CUTOUT"
    case clipboard = "CLIPBOARD"
    case audioExtract = "AUDIO"
    case gif = "GIF"
    case pngPages = "PNG_PAGES"
    case extractText = "TEXT_OCR"

    public var id: String { rawValue }
}

public struct TargetFormatSlice: Identifiable, Equatable {
    public let id: Int
    public let type: OutputFormatType
    public let label: String
    public let sublabel: String
    public let benefitTag: String
    public let iconName: String
    public let isAIPowered: Bool
    public let accentColor: Color
    public let supportsQualitySlider: Bool

    public init(
        id: Int,
        type: OutputFormatType,
        label: String,
        sublabel: String,
        benefitTag: String,
        iconName: String,
        isAIPowered: Bool = false,
        accentColor: Color,
        supportsQualitySlider: Bool = false
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.sublabel = sublabel
        self.benefitTag = benefitTag
        self.iconName = iconName
        self.isAIPowered = isAIPowered
        self.accentColor = accentColor
        self.supportsQualitySlider = supportsQualitySlider
    }
}

public final class FormatResolver {
    /// Resolves optimal output formats given an input file URL
    public static func resolveTargets(for sourceURL: URL) -> [TargetFormatSlice] {
        let ext = sourceURL.pathExtension.lowercased()

        // 1. Image Files (HEIC, PNG, JPG, WebP, TIFF, BMP)
        if ["png", "jpg", "jpeg", "heic", "webp", "tiff", "bmp"].contains(ext) {
            var targets: [TargetFormatSlice] = []
            var nextId = 0

            // WebP
            if ext != "webp" {
                targets.append(TargetFormatSlice(
                    id: nextId,
                    type: .webp,
                    label: "WebP",
                    sublabel: "Compact Web",
                    benefitTag: "⚡ ~75% Smaller",
                    iconName: "sparkles",
                    accentColor: DonutTheme.webpCyan,
                    supportsQualitySlider: true
                ))
                nextId += 1
            }

            // AI Cutout (Apple Vision Background Removal)
            targets.append(TargetFormatSlice(
                id: nextId,
                type: .cutoutPNG,
                label: "Cutout",
                sublabel: "Remove BG",
                benefitTag: "✨ Instant Transparent PNG",
                iconName: "wand.and.stars",
                isAIPowered: true,
                accentColor: DonutTheme.cutoutViolet
            ))
            nextId += 1

            // PNG (Lossless)
            if ext != "png" {
                targets.append(TargetFormatSlice(
                    id: nextId,
                    type: .png,
                    label: "PNG",
                    sublabel: "Lossless Master",
                    benefitTag: "💎 100% Quality",
                    iconName: "photo",
                    accentColor: DonutTheme.pngEmerald
                ))
                nextId += 1
            }

            // JPG (Universal Photo)
            if ext != "jpg" && ext != "jpeg" {
                targets.append(TargetFormatSlice(
                    id: nextId,
                    type: .jpg,
                    label: "JPG",
                    sublabel: "Universal Photo",
                    benefitTag: "📸 Share Anywhere",
                    iconName: "photo.fill",
                    accentColor: DonutTheme.jpgAmber,
                    supportsQualitySlider: true
                ))
                nextId += 1
            }

            // PDF Document
            targets.append(TargetFormatSlice(
                id: nextId,
                type: .pdf,
                label: "PDF",
                sublabel: "Document",
                benefitTag: "📄 Print-Ready",
                iconName: "doc.richtext",
                accentColor: DonutTheme.pdfRuby
            ))
            nextId += 1

            // AI OCR Text Extraction on Images
            targets.append(TargetFormatSlice(
                id: nextId,
                type: .extractText,
                label: "OCR Text",
                sublabel: "Extract Text",
                benefitTag: "📝 Copy Text from Image",
                iconName: "text.viewfinder",
                isAIPowered: true,
                accentColor: DonutTheme.webpCyan
            ))
            nextId += 1

            // Direct to Clipboard (Zero disk clutter)
            targets.append(TargetFormatSlice(
                id: nextId,
                type: .clipboard,
                label: "Copy",
                sublabel: "To Clipboard",
                benefitTag: "📋 Ready to Paste (⌘V)",
                iconName: "doc.on.clipboard",
                accentColor: DonutTheme.clipboardTeal
            ))

            return targets
        }

        // 2. Video Files (MP4, MOV, M4V, WEBM)
        if ["mp4", "mov", "m4v", "webm"].contains(ext) {
            return [
                TargetFormatSlice(
                    id: 0,
                    type: .audioExtract,
                    label: "Audio",
                    sublabel: "Extract M4A",
                    benefitTag: "🎵 Clean Audio Track",
                    iconName: "waveform",
                    accentColor: DonutTheme.audioPurple
                ),
                TargetFormatSlice(
                    id: 1,
                    type: .gif,
                    label: "GIF",
                    sublabel: "Animated Loop",
                    benefitTag: "🎞️ Looping Animation",
                    iconName: "play.square.stack",
                    accentColor: DonutTheme.gifOrange
                ),
                TargetFormatSlice(
                    id: 2,
                    type: .clipboard,
                    label: "Copy",
                    sublabel: "To Clipboard",
                    benefitTag: "📋 Copy Video File",
                    iconName: "doc.on.clipboard",
                    accentColor: DonutTheme.clipboardTeal
                )
            ]
        }

        // 3. PDF Documents
        if ext == "pdf" {
            return [
                TargetFormatSlice(
                    id: 0,
                    type: .pngPages,
                    label: "PNGs",
                    sublabel: "Render Pages",
                    benefitTag: "🖼️ High-Res PNGs",
                    iconName: "photo.stack",
                    accentColor: DonutTheme.pngEmerald
                ),
                TargetFormatSlice(
                    id: 1,
                    type: .extractText,
                    label: "OCR Text",
                    sublabel: "Extract Text",
                    benefitTag: "📝 Copy All Text",
                    iconName: "text.viewfinder",
                    isAIPowered: true,
                    accentColor: DonutTheme.webpCyan
                ),
                TargetFormatSlice(
                    id: 2,
                    type: .clipboard,
                    label: "Copy",
                    sublabel: "First Page",
                    benefitTag: "📋 Copy to Clipboard",
                    iconName: "doc.on.clipboard",
                    accentColor: DonutTheme.clipboardTeal
                )
            ]
        }

        // Default Fallback
        return [
            TargetFormatSlice(
                id: 0,
                type: .clipboard,
                label: "Copy",
                sublabel: "To Clipboard",
                benefitTag: "📋 Copy File",
                iconName: "doc.on.clipboard",
                accentColor: DonutTheme.clipboardTeal
            )
        ]
    }
}
