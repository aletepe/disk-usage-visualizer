import Foundation
import SwiftUI

struct WedgeLayout: Identifiable {
    let id: UUID
    let node: Node
    let ringIndex: Int
    let startAngle: Double
    let endAngle: Double
    let hue: Double
}

enum WedgeGeometry {
    static let twoPi = 2.0 * Double.pi

    private static let palette: [Double] = [
        0.00, 0.06, 0.11, 0.15, 0.22, 0.36,
        0.48, 0.55, 0.61, 0.70, 0.78, 0.91
    ]

    static func computeLayouts(focusedRoot: Node, maxRings: Int, minAngle: Double) -> [WedgeLayout] {
        var out: [WedgeLayout] = []
        out.append(WedgeLayout(id: focusedRoot.id, node: focusedRoot, ringIndex: 0, startAngle: 0, endAngle: twoPi, hue: 0))
        recurse(parent: focusedRoot, ring: 1, start: 0, end: twoPi, parentHue: nil, maxRings: maxRings, minAngle: minAngle, into: &out)
        return out
    }

    private static func recurse(parent: Node, ring: Int, start: Double, end: Double, parentHue: Double?, maxRings: Int, minAngle: Double, into out: inout [WedgeLayout]) {
        guard ring < maxRings else { return }
        let parentSize = parent.totalSize
        guard parentSize > 0 else { return }
        let span = end - start
        var cursor = start
        for child in parent.children {
            let frac = Double(child.totalSize) / Double(parentSize)
            let childSpan = span * frac
            let childEnd = cursor + childSpan
            if childSpan >= minAngle {
                let hue = childHue(for: child, parentHue: parentHue)
                out.append(WedgeLayout(id: child.id, node: child, ringIndex: ring, startAngle: cursor, endAngle: childEnd, hue: hue))
                if child.isDirectory && !child.children.isEmpty {
                    recurse(parent: child, ring: ring + 1, start: cursor, end: childEnd, parentHue: hue, maxRings: maxRings, minAngle: minAngle, into: &out)
                }
            }
            cursor = childEnd
        }
    }

    private static func childHue(for node: Node, parentHue: Double?) -> Double {
        var hasher = Hasher()
        hasher.combine(node.path)
        let h = abs(hasher.finalize())
        if let parentHue {
            let jitter = (Double(h % 1000) / 1000.0 - 0.5) * 0.06
            var hue = parentHue + jitter
            if hue < 0 { hue += 1 }
            if hue >= 1 { hue -= 1 }
            return hue
        }
        return palette[h % palette.count]
    }

    static func hitTest(layouts: [WedgeLayout], at point: CGPoint, center: CGPoint, innerRadius: Double, ringWidth: Double) -> WedgeLayout? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = sqrt(dx * dx + dy * dy)
        if r < innerRadius {
            return layouts.first { $0.ringIndex == 0 }
        }
        let ringIndex = Int(floor((r - innerRadius) / ringWidth)) + 1
        var theta = atan2(dy, dx) + .pi / 2
        if theta < 0 { theta += twoPi }
        if theta >= twoPi { theta -= twoPi }
        for layout in layouts where layout.ringIndex == ringIndex {
            if theta >= layout.startAngle && theta <= layout.endAngle {
                return layout
            }
        }
        return nil
    }

    static func annularWedgePath(center: CGPoint, innerRadius: Double, outerRadius: Double, startAngle: Double, endAngle: Double) -> Path {
        let s = Angle(radians: startAngle - .pi / 2)
        let e = Angle(radians: endAngle - .pi / 2)
        var p = Path()
        let isx = center.x + cos(s.radians) * innerRadius
        let isy = center.y + sin(s.radians) * innerRadius
        p.move(to: CGPoint(x: isx, y: isy))
        let osx = center.x + cos(s.radians) * outerRadius
        let osy = center.y + sin(s.radians) * outerRadius
        p.addLine(to: CGPoint(x: osx, y: osy))
        p.addArc(center: center, radius: outerRadius, startAngle: s, endAngle: e, clockwise: false)
        let iex = center.x + cos(e.radians) * innerRadius
        let iey = center.y + sin(e.radians) * innerRadius
        p.addLine(to: CGPoint(x: iex, y: iey))
        p.addArc(center: center, radius: innerRadius, startAngle: e, endAngle: s, clockwise: true)
        p.closeSubpath()
        return p
    }

    static func wedgeColor(for layout: WedgeLayout) -> Color {
        let r = max(1, layout.ringIndex)
        let saturation = max(0.42, 0.66 - Double(r - 1) * 0.045)
        let brightness = max(0.62, 0.88 - Double(r - 1) * 0.045)
        return Color(hue: layout.hue, saturation: saturation, brightness: brightness)
    }
}
