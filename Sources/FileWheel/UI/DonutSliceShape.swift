import SwiftUI

public struct DonutSliceShape: Shape {
    public let sliceIndex: Int
    public let totalSlices: Int
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat
    public let gapDegrees: Double

    public init(
        sliceIndex: Int,
        totalSlices: Int,
        innerRadius: CGFloat = DonutGeometry.innerRadius,
        outerRadius: CGFloat = DonutGeometry.outerRadius,
        gapDegrees: Double = 2.0
    ) {
        self.sliceIndex = sliceIndex
        self.totalSlices = totalSlices
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.gapDegrees = gapDegrees
    }

    public func path(in rect: CGRect) -> Path {
        guard totalSlices > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let sliceAngle = 360.0 / Double(totalSlices)

        let midAngle = -90.0 + (Double(sliceIndex) * sliceAngle)
        let startAngle = Angle.degrees(midAngle - (sliceAngle / 2.0) + (gapDegrees / 2.0))
        let endAngle   = Angle.degrees(midAngle + (sliceAngle / 2.0) - (gapDegrees / 2.0))

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
