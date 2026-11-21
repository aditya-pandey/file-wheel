import SwiftUI
import AppKit

public struct DonutView: View {
    public let sourceURL: URL?
    public let targets: [TargetFormatSlice]
    public let activeSliceIndex: Int?
    public let currentQuality: Float
    public let isQualitySliderActive: Bool
    public let isConverting: Bool
    public let isSuccess: Bool
    public let errorMessage: String?

    @State private var appeared: Bool = false

    private let size = DonutGeometry.donutDiameter

    public init(
        sourceURL: URL?,
        targets: [TargetFormatSlice],
        activeSliceIndex: Int?,
        currentQuality: Float = 0.85,
        isQualitySliderActive: Bool = false,
        isConverting: Bool = false,
        isSuccess: Bool = false,
        errorMessage: String? = nil
    ) {
        self.sourceURL = sourceURL
        self.targets = targets
        self.activeSliceIndex = activeSliceIndex
        self.currentQuality = currentQuality
        self.isQualitySliderActive = isQualitySliderActive
        self.isConverting = isConverting
        self.isSuccess = isSuccess
        self.errorMessage = errorMessage
    }

    public var body: some View {
        ZStack {
            // ━━ Layer 1: Subtle Platinum & Anodized Atmosphere ━━
            let activeColor = activeSliceIndex.flatMap { idx in targets.first(where: { $0.id == idx })?.accentColor } ?? Color.clear

            Circle()
                .fill(activeColor.opacity(0.11))
                .frame(width: DonutGeometry.outerRadius * 2 + 36, height: DonutGeometry.outerRadius * 2 + 36)
                .blur(radius: 34)
                .animation(.easeInOut(duration: 0.25), value: activeSliceIndex)

            // Deep Drop Shadow
            Circle()
                .fill(Color.black.opacity(0.70))
                .frame(width: DonutGeometry.outerRadius * 2 + 10, height: DonutGeometry.outerRadius * 2 + 10)
                .blur(radius: 30)

            // ━━ Layer 2: Ring Slices ━━
            ForEach(targets) { target in
                let isSelected = (activeSliceIndex == target.id)
                sliceView(for: target, isSelected: isSelected)
            }

            // ━━ Layer 3: Interactive Outer Quality Slider ━━
            if let activeIdx = activeSliceIndex,
               let target = targets.first(where: { $0.id == activeIdx }),
               target.supportsQualitySlider,
               !isConverting {
                QualityArcSliderView(
                    sliceIndex: target.id,
                    totalSlices: targets.count,
                    quality: currentQuality,
                    accentColor: target.accentColor
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
            }

            // ━━ Layer 4: Central Metallic Hub ━━
            DonutCenterHubView(
                sourceURL: sourceURL,
                activeSlice: activeSliceIndex.flatMap { idx in targets.first(where: { $0.id == idx }) },
                totalSlices: targets.count,
                currentQuality: currentQuality,
                isQualitySliderActive: isQualitySliderActive,
                isConverting: isConverting,
                isSuccess: isSuccess,
                errorMessage: errorMessage
            )
        }
        .frame(width: size, height: size)
        .scaleEffect(appeared ? 1.0 : 0.78)
        .rotationEffect(.degrees(appeared ? 0 : -10))
        .opacity(appeared ? 1.0 : 0.0)
        .blur(radius: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.68)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private func sliceView(for target: TargetFormatSlice, isSelected: Bool) -> some View {
        let outer = isSelected ? DonutGeometry.outerRadius + 12 : DonutGeometry.outerRadius
        let inner = isSelected ? DonutGeometry.innerRadius - 3 : DonutGeometry.innerRadius

        let dimOthers = isConverting && !isSelected

        ZStack {
            // Slice shape fill
            DonutSliceShape(
                sliceIndex: target.id,
                totalSlices: targets.count,
                innerRadius: inner,
                outerRadius: outer,
                gapDegrees: 2.2
            )
            .fill(
                isSelected
                    ? AnyShapeStyle(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                DonutTheme.platinumIce.opacity(0.20),
                                target.accentColor.opacity(0.12),
                                DonutTheme.ringSliceHover
                            ]),
                            center: .center,
                            startRadius: inner,
                            endRadius: outer
                        )
                    )
                    : AnyShapeStyle(DonutTheme.ringBodyFill)
            )
            .overlay(
                DonutSliceShape(
                    sliceIndex: target.id,
                    totalSlices: targets.count,
                    innerRadius: inner,
                    outerRadius: outer,
                    gapDegrees: 2.2
                )
                .stroke(
                    isSelected ? DonutTheme.platinumIce.opacity(0.62) : DonutTheme.ringEdgeStroke,
                    lineWidth: isSelected ? 1.5 : 0.9
                )
            )
            .shadow(
                color: isSelected ? target.accentColor.opacity(0.28) : .clear,
                radius: 10
            )

            // Slice Content (Icon, Label, AI Badge)
            sliceContent(for: target, isSelected: isSelected)
        }
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .opacity(dimOthers ? 0.15 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.70), value: isSelected)
        .animation(.easeInOut(duration: 0.18), value: dimOthers)
    }

    @ViewBuilder
    private func sliceContent(for target: TargetFormatSlice, isSelected: Bool) -> some View {
        let pos = DonutGeometry.point(
            forSlice: target.id,
            totalSlices: targets.count,
            radius: DonutGeometry.iconRadius + (isSelected ? 5 : 0)
        )

        VStack(spacing: 2.5) {
            Image(systemName: target.iconName)
                .font(.system(size: isSelected ? 18.5 : 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.white : DonutTheme.iconResting)
                .shadow(color: isSelected ? DonutTheme.platinumIce.opacity(0.45) : .clear, radius: 6)

            Text(target.label)
                .font(.system(size: isSelected ? 11.5 : 10.5, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? DonutTheme.textPrimary : Color(white: 0.66))

            if target.isAIPowered {
                Text("AI")
                    .font(.system(size: 7.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? DonutTheme.platinumIce : Color(white: 0.56))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(isSelected ? 0.14 : 0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white.opacity(isSelected ? 0.28 : 0.12), lineWidth: 0.8)
                    )
            }
        }
        .offset(x: pos.x, y: pos.y)
        .animation(.spring(response: 0.18, dampingFraction: 0.70), value: isSelected)
    }
}
