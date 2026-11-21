import SwiftUI

public struct QualityArcSliderView: View {
    public let sliceIndex: Int
    public let totalSlices: Int
    public let quality: Float // 0.50 to 1.00
    public let accentColor: Color

    private let midRadius: CGFloat = 208.0
    private let barWidth: CGFloat = 26.0

    public init(sliceIndex: Int, totalSlices: Int, quality: Float, accentColor: Color) {
        self.sliceIndex = sliceIndex
        self.totalSlices = totalSlices
        self.quality = max(0.50, min(1.00, quality))
        self.accentColor = accentColor
    }

    public var body: some View {
        let sliceAngle = 360.0 / Double(totalSlices)
        let midAngle = -90.0 + (Double(sliceIndex) * sliceAngle)
        let arcSpan = sliceAngle * 0.82
        let startAngle = Angle.degrees(midAngle - (arcSpan / 2.0))
        let endAngle = Angle.degrees(midAngle + (arcSpan / 2.0))

        ZStack {
            // Dark capsule track background
            DynamicArcShape(
                radius: midRadius,
                startAngle: startAngle,
                endAngle: endAngle
            )
            .stroke(
                DonutTheme.obsidianDark,
                style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
            )
            .overlay(
                DynamicArcShape(
                    radius: midRadius,
                    startAngle: startAngle,
                    endAngle: endAngle
                )
                .stroke(
                    DonutTheme.ringEdgeStroke,
                    style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
                )
            )
            .shadow(color: Color.black.opacity(0.6), radius: 10, x: 0, y: 4)

            // Recessed track
            DynamicArcShape(
                radius: midRadius,
                startAngle: startAngle,
                endAngle: endAngle
            )
            .stroke(
                Color.black.opacity(0.7),
                style: StrokeStyle(lineWidth: 6.0, lineCap: .round)
            )

            // Active Quality fill bar
            // Normalized quality [0.50, 1.00] -> [0.0, 1.0]
            let normalized = Double((quality - 0.50) / 0.50)
            let fillEndDeg = (midAngle - (arcSpan / 2.0)) + (normalized * arcSpan)

            DynamicArcShape(
                radius: midRadius,
                startAngle: startAngle,
                endAngle: Angle.degrees(fillEndDeg)
            )
            .stroke(
                accentColor,
                style: StrokeStyle(lineWidth: 6.0, lineCap: .round)
            )
            .shadow(color: accentColor.opacity(0.7), radius: 8)

            // Glowing Indicator Pill at current quality
            DynamicArcShape(
                radius: midRadius,
                startAngle: Angle.degrees(max(startAngle.degrees, fillEndDeg - 4.0)),
                endAngle: Angle.degrees(min(endAngle.degrees, fillEndDeg + 4.0))
            )
            .stroke(
                Color.white,
                style: StrokeStyle(lineWidth: 9.0, lineCap: .round)
            )
            .shadow(color: Color.white.opacity(0.8), radius: 6)
        }
        .frame(width: DonutGeometry.donutDiameter, height: DonutGeometry.donutDiameter)
    }
}

struct DynamicArcShape: Shape {
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
