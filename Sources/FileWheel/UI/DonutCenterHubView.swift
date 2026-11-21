import SwiftUI
import AppKit

public struct DonutCenterHubView: View {
    public let sourceURL: URL?
    public let activeSlice: TargetFormatSlice?
    public let totalSlices: Int
    public let currentQuality: Float
    public let isQualitySliderActive: Bool
    public let isConverting: Bool
    public let isSuccess: Bool
    public let errorMessage: String?

    private let hubRadius: CGFloat = DonutGeometry.deadZoneRadius
    private let borderWidth: CGFloat = 3.2

    public var body: some View {
        ZStack {
            // Metallic Outer Bevel Ring (Gunmetal Titanium)
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            DonutTheme.metallicHi,
                            DonutTheme.metallicLo,
                            DonutTheme.metallicMid,
                            DonutTheme.metallicHi,
                            DonutTheme.metallicLo,
                            DonutTheme.metallicHi,
                        ]),
                        center: .center
                    ),
                    lineWidth: borderWidth
                )
                .frame(width: hubRadius * 2, height: hubRadius * 2)

            // Inner Shadow for concave depth
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            DonutTheme.hubCenterFill,
                            Color.black.opacity(0.95)
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: hubRadius
                    )
                )
                .frame(width: (hubRadius - borderWidth) * 2, height: (hubRadius - borderWidth) * 2)

            // Precision 24-Tick Chronograph Bezel Ring
            ZStack {
                ForEach(0..<24, id: \.self) { i in
                    let isCardinal = (i % 3 == 0)
                    Rectangle()
                        .fill(Color.white.opacity(isCardinal ? 0.16 : 0.06))
                        .frame(width: isCardinal ? 1.1 : 0.8, height: isCardinal ? 4.0 : 2.2)
                        .offset(y: -(hubRadius - 6.0))
                        .rotationEffect(.degrees(Double(i) * (360.0 / 24.0)))
                }
            }

            // Dynamic Active Arc Glow on the Hub Rim
            if let target = activeSlice, !isConverting && !isSuccess && errorMessage == nil {
                selectionRimGlow(for: target)
            }

            // ━━ State 1: Error Message ━━
            if let error = errorMessage {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.yellow)

                    Text(error)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6)
                }
                .transition(.scale.combined(with: .opacity))
            }
            // ━━ State 2: Converting Spinner ━━
            else if isConverting {
                VStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: activeSlice?.accentColor ?? DonutTheme.webpCyan))
                        .scaleEffect(1.2)

                    Text("Processing...")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .transition(.scale.combined(with: .opacity))
            }
            // ━━ State 3: Conversion Success Checkmark ━━
            else if isSuccess {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DonutTheme.pngEmerald)
                        .shadow(color: DonutTheme.pngEmerald.opacity(0.6), radius: 8)

                    Text("Saved!")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            // ━━ State 4: Quality Slider Readout ━━
            else if isQualitySliderActive, let target = activeSlice {
                VStack(spacing: 2) {
                    Text("\(target.label) Quality")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(target.accentColor)

                    Text("\(Int(round(currentQuality * 100)))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .monospacedDigit()

                    Text("Drag to adjust")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
                .transition(.opacity)
            }
            // ━━ State 5: Target Hovered (Benefit Readout) ━━
            else if let target = activeSlice {
                VStack(spacing: 3) {
                    Image(systemName: target.iconName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(target.accentColor)
                        .shadow(color: target.accentColor.opacity(0.6), radius: 8)

                    Text(target.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Text(target.benefitTag)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(target.isAIPowered ? DonutTheme.cutoutViolet : Color.white.opacity(0.65))
                        .lineLimit(1)
                }
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
            // ━━ State 6: Idle (Source File Info) ━━
            else if let url = sourceURL {
                VStack(spacing: 3) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)

                    Text(url.lastPathComponent)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 10)

                    Text(fileSizeString(for: url))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(DonutTheme.textMuted)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color(white: 0.40))
                    Text("Drop on a slice")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.35))
                }
            }
        }
        .frame(width: hubRadius * 2 + 8, height: hubRadius * 2 + 8)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: activeSlice?.id)
        .animation(.spring(response: 0.20, dampingFraction: 0.70), value: isConverting)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSuccess)
        .animation(.easeInOut(duration: 0.20), value: errorMessage != nil)
    }

    @ViewBuilder
    private func selectionRimGlow(for target: TargetFormatSlice) -> some View {
        let sliceAngle = 360.0 / Double(max(1, totalSlices))
        let midAngle = -90.0 + (Double(target.id) * sliceAngle)
        let arcStart = Angle.degrees(midAngle - (sliceAngle / 2.0) + 4.0)
        let arcEnd   = Angle.degrees(midAngle + (sliceAngle / 2.0) - 4.0)

        HubRimArcShape(startAngle: arcStart, endAngle: arcEnd)
            .stroke(
                DonutTheme.platinumIce,
                style: StrokeStyle(lineWidth: 2.8, lineCap: .round)
            )
            .frame(width: hubRadius * 2, height: hubRadius * 2)
            .shadow(color: target.accentColor.opacity(0.55), radius: 6, x: 0, y: 0)
    }

    private func fileSizeString(for url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

public struct HubRimArcShape: Shape {
    public let startAngle: Angle
    public let endAngle: Angle

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}
