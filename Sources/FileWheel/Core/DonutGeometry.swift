import Foundation
import CoreGraphics
import AppKit

public struct DonutGeometry {
    public static let deadZoneRadius: CGFloat = 65.0
    public static let innerRadius: CGFloat    = 72.0
    public static let outerRadius: CGFloat    = 175.0
    public static let iconRadius: CGFloat     = 124.0
    public static let donutDiameter: CGFloat  = 460.0

    /// Evaluates polar coordinates (radius, sliceIndex) from relative point (dx, dy)
    /// In AppKit screen coordinates, dy increases UPWARDS.
    public static func evaluate(dx: CGFloat, dy: CGFloat, sliceCount: Int) -> (radius: CGFloat, sliceIndex: Int?) {
        let radius = hypot(dx, dy)

        guard radius >= deadZoneRadius && sliceCount > 0 else {
            return (radius, nil)
        }

        let mathAngle = atan2(dy, dx)
        var degrees = mathAngle * 180.0 / .pi
        if degrees < 0 { degrees += 360.0 }

        // Cartesian -> Compass: (90 - Cartesian) mod 360
        var compassDegrees = 90.0 - degrees
        if compassDegrees < 0 { compassDegrees += 360.0 }

        let sliceAngle = 360.0 / Double(sliceCount)
        let shifted = compassDegrees + (sliceAngle / 2.0)
        let index = Int(shifted / sliceAngle) % sliceCount

        return (radius, index)
    }

    /// Clamps donut center so the panel stays fully visible on the active screen
    public static func clampToScreen(center: CGPoint, panelSize: CGSize) -> CGPoint {
        guard let screen = NSScreen.screens.first(where: { NSPointInRect(center, $0.frame) }) ?? NSScreen.main else {
            return center
        }

        let visibleFrame = screen.visibleFrame
        let halfW = panelSize.width / 2.0
        let halfH = panelSize.height / 2.0
        let margin: CGFloat = 10.0

        let clampedX = min(max(center.x, visibleFrame.minX + halfW + margin), visibleFrame.maxX - halfW - margin)
        let clampedY = min(max(center.y, visibleFrame.minY + halfH + margin), visibleFrame.maxY - halfH - margin)

        return CGPoint(x: clampedX, y: clampedY)
    }

    public static func point(forSlice index: Int, totalSlices: Int, radius: CGFloat) -> CGPoint {
        guard totalSlices > 0 else { return .zero }
        let sliceAngle = 360.0 / Double(totalSlices)
        let angleDeg = -90.0 + (Double(index) * sliceAngle)
        let angleRad = angleDeg * .pi / 180.0
        return CGPoint(x: radius * cos(angleRad), y: radius * sin(angleRad))
    }
}
