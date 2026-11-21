import AppKit
import SwiftUI

public final class DonutDropPanel: NSPanel, NSDraggingDestination {
    private var hostingView: NSHostingView<AnyView>?
    private var anchorPoint: CGPoint = .zero

    private var currentSourceURL: URL?
    private var currentTargets: [TargetFormatSlice] = []
    private var currentActiveSlice: Int? = nil

    private var currentQuality: Float = 0.85
    private var isQualitySliderActive: Bool = false
    private var isConverting: Bool = false
    private var isSuccess: Bool = false
    private var errorMessage: String? = nil
    private var lastHapticQualityStep: Int = 8

    public var onConversionComplete: ((URL) -> Void)?

    public init() {
        let size = DonutGeometry.donutDiameter
        let initialRect = NSRect(x: 0, y: 0, width: size, height: size)

        super.init(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .popUpMenu
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        registerForDraggedTypes([
            .fileURL,
            .URL,
            .pdf,
            .png,
            .tiff,
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])

        renderDonut()
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }

    public func present(at cursorPoint: CGPoint) {
        let size = CGSize(width: DonutGeometry.donutDiameter, height: DonutGeometry.donutDiameter)
        let clampedCenter = DonutGeometry.clampToScreen(center: cursorPoint, panelSize: size)
        self.anchorPoint = clampedCenter

        let origin = CGPoint(
            x: clampedCenter.x - (size.width / 2.0),
            y: clampedCenter.y - (size.height / 2.0)
        )
        self.setFrameOrigin(origin)
        self.currentActiveSlice = nil
        self.currentQuality = 0.85
        self.isQualitySliderActive = false
        self.isConverting = false
        self.isSuccess = false
        self.errorMessage = nil

        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    public func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1.0
            self?.isConverting = false
            self?.isSuccess = false
            self?.errorMessage = nil
        })
        self.currentActiveSlice = nil
        self.currentSourceURL = nil
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - NSDraggingDestination Handlers
    // ─────────────────────────────────────────────────────────────

    private func extractDraggedFileURL(from sender: NSDraggingInfo) -> URL? {
        let pb = sender.draggingPasteboard

        // 1. Standard file URL objects
        if let fileURLs = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let first = fileURLs.first {
            return first
        }

        // 2. Legacy NSFilenamesPboardType array (used by some macOS apps like Preview / older Finder drags)
        if let filenames = pb.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String],
           let firstPath = filenames.first {
            return URL(fileURLWithPath: firstPath)
        }

        // 3. Raw PDF data dragged from Preview / Browser
        if let pdfData = pb.data(forType: .pdf) {
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DraggedDocument.pdf")
            if (try? pdfData.write(to: tmpURL)) != nil {
                return tmpURL
            }
        }

        // 4. Raw PNG / TIFF image dragged from a Browser
        if let pngData = pb.data(forType: .png) {
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DraggedImage.png")
            if (try? pngData.write(to: tmpURL)) != nil {
                return tmpURL
            }
        }
        if let tiffData = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiffData),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DraggedImage.png")
            if (try? pngData.write(to: tmpURL)) != nil {
                return tmpURL
            }
        }

        return nil
    }

    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let firstURL = extractDraggedFileURL(from: sender) else {
            return []
        }

        self.currentSourceURL = firstURL
        self.currentTargets = FormatResolver.resolveTargets(for: firstURL)
        self.currentQuality = 0.85
        self.isQualitySliderActive = false
        self.isConverting = false
        self.isSuccess = false
        self.errorMessage = nil
        renderDonut()

        return .copy
    }

    public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !isConverting && errorMessage == nil else { return [] }

        let mouseLocation = NSEvent.mouseLocation
        let dx = mouseLocation.x - anchorPoint.x
        let dy = mouseLocation.y - anchorPoint.y

        let (radius, sliceIndex) = DonutGeometry.evaluate(dx: dx, dy: dy, sliceCount: currentTargets.count)

        // Check if cursor is pushing outward into the Quality Arc Slider
        if let idx = sliceIndex, idx < currentTargets.count, currentTargets[idx].supportsQualitySlider {
            if radius > DonutGeometry.outerRadius {
                self.isQualitySliderActive = true

                let clampedDistance = max(DonutGeometry.outerRadius, min(DonutGeometry.outerRadius + 45.0, radius))
                let ratio = Float((clampedDistance - DonutGeometry.outerRadius) / 45.0)
                let newQuality = 0.50 + (ratio * 0.50)

                if abs(newQuality - currentQuality) > 0.02 {
                    self.currentQuality = newQuality
                    let step = Int(round(newQuality * 10))
                    if step != lastHapticQualityStep {
                        lastHapticQualityStep = step
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                }
            } else {
                self.isQualitySliderActive = false
            }
        } else {
            self.isQualitySliderActive = false
        }

        if sliceIndex != currentActiveSlice {
            self.currentActiveSlice = sliceIndex

            if sliceIndex != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }

            renderDonut()
        } else if isQualitySliderActive {
            renderDonut()
        }

        return .copy
    }

    public func draggingExited(_ sender: NSDraggingInfo?) {
        guard !isConverting && errorMessage == nil else { return }
        self.currentActiveSlice = nil
        self.isQualitySliderActive = false
        renderDonut()
    }

    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let sliceIndex = currentActiveSlice,
              sliceIndex >= 0 && sliceIndex < currentTargets.count,
              let sourceURL = currentSourceURL else {
            dismiss()
            return false
        }

        let target = currentTargets[sliceIndex]
        let selectedQuality = currentQuality

        // ━━ Rich Drop Motion: Lock slice & pulse converting state ━━
        self.isConverting = true
        self.isQualitySliderActive = false
        self.errorMessage = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        renderDonut()

        // Execute conversion on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.executeConversion(sourceURL: sourceURL, target: target, quality: selectedQuality)
        }

        return true
    }

    // ─────────────────────────────────────────────────────────────
    // MARK: - Conversion Execution Pipeline
    // ─────────────────────────────────────────────────────────────

    private func executeConversion(sourceURL: URL, target: TargetFormatSlice, quality: Float) {
        let ext = sourceURL.pathExtension.lowercased()

        do {
            var resultingURL: URL?

            switch target.type {
            case .cutoutPNG:
                resultingURL = try VisionCutoutEngine.removeBackground(sourceURL: sourceURL)

            case .pngPages:
                resultingURL = try PDFConverterEngine.renderPagesToPNG(sourceURL: sourceURL)

            case .extractText:
                if ext == "pdf" {
                    resultingURL = try PDFConverterEngine.extractText(sourceURL: sourceURL)
                } else {
                    resultingURL = try ImageConverter.convert(
                        sourceURL: sourceURL,
                        targetType: .extractText,
                        customQuality: quality
                    )
                }

            case .clipboard:
                if ext == "pdf" {
                    try PDFConverterEngine.copyFirstPage(sourceURL: sourceURL)
                    resultingURL = nil
                } else if ["mp4", "mov", "m4v", "webm"].contains(ext) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([sourceURL as NSURL])
                    resultingURL = nil
                } else {
                    resultingURL = try ImageConverter.convert(
                        sourceURL: sourceURL,
                        targetType: .clipboard,
                        customQuality: quality
                    )
                }

            case .gif:
                MediaConverter.convertToGIF(sourceURL: sourceURL) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            self?.handleSuccess(url: url)
                        case .failure(let error):
                            self?.handleError(message: error.localizedDescription)
                        }
                    }
                }
                return

            case .audioExtract:
                MediaConverter.extractAudio(sourceURL: sourceURL) { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            self?.handleSuccess(url: url)
                        case .failure(let error):
                            self?.handleError(message: error.localizedDescription)
                        }
                    }
                }
                return

            default:
                resultingURL = try ImageConverter.convert(
                    sourceURL: sourceURL,
                    targetType: target.type,
                    customQuality: quality
                )
            }

            if let finalURL = resultingURL {
                DispatchQueue.main.async { [weak self] in
                    self?.handleSuccess(url: finalURL)
                }
            } else {
                // Clipboard or in-memory
                DispatchQueue.main.async { [weak self] in
                    self?.handleSuccess(url: nil)
                }
            }
        } catch {
            print("[DonutDropPanel] Conversion failed: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.handleError(message: error.localizedDescription)
            }
        }
    }

    private func handleSuccess(url: URL?) {
        self.isConverting = false
        self.isSuccess = true
        self.errorMessage = nil
        renderDonut()

        // Play subtle success chime
        NSSound(named: "Glass")?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        if let fileURL = url {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            onConversionComplete?(fileURL)
        }

        // Graceful departure after showing success checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.dismiss()
        }
    }

    private func handleError(message: String) {
        self.isConverting = false
        self.isSuccess = false
        self.errorMessage = message
        renderDonut()

        // Play alert sound & haptic
        NSSound(named: "Basso")?.play()
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)

        // Give the user 1.8s to see the error message in the center hub
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.dismiss()
        }
    }

    private func renderDonut() {
        let rootView = DonutView(
            sourceURL: currentSourceURL,
            targets: currentTargets,
            activeSliceIndex: currentActiveSlice,
            currentQuality: currentQuality,
            isQualitySliderActive: isQualitySliderActive,
            isConverting: isConverting,
            isSuccess: isSuccess,
            errorMessage: errorMessage
        )

        let wrapped = AnyView(rootView)
        if let existing = hostingView {
            existing.rootView = wrapped
        } else {
            let host = NSHostingView(rootView: wrapped)
            host.frame = NSRect(x: 0, y: 0, width: DonutGeometry.donutDiameter, height: DonutGeometry.donutDiameter)
            self.contentView = host
            self.hostingView = host
        }
    }
}
