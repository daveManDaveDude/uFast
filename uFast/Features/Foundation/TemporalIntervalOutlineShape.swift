import SwiftUI

/// Strokes only the visible outer boundary of an interval fragment.
///
/// Day-local fragments need closed fill geometry so their colour reaches the
/// page edge, but a closed stroke would add an internal vertical rule at every
/// midnight seam. This path leaves continuation edges open while retaining the
/// real rounded start and end caps.
struct TemporalIntervalOutlineShape: Shape {
    let continuesBefore: Bool
    let continuesAfter: Bool
    let cornerRadius: Double

    func path(in rect: CGRect) -> Path {
        let capCount = [!continuesBefore, !continuesAfter].count(where: { $0 })
        let availableWidth = capCount > 1 ? rect.width / 2 : rect.width
        let radius = min(
            max(cornerRadius, 0),
            availableWidth,
            rect.height / 2
        )
        let leadingRadius = continuesBefore ? 0 : radius
        let trailingRadius = continuesAfter ? 0 : radius
        var path = Path()

        if leadingRadius > 0 {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + leadingRadius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + leadingRadius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        }

        path.addLine(to: CGPoint(x: rect.maxX - trailingRadius, y: rect.minY))
        if trailingRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + trailingRadius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - trailingRadius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - trailingRadius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }

        path.addLine(to: CGPoint(x: rect.minX + leadingRadius, y: rect.maxY))
        if leadingRadius > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - leadingRadius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + leadingRadius))
        }

        return path
    }
}
