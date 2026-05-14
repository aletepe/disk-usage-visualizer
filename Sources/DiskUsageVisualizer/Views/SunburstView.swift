import SwiftUI

struct SunburstView: View {
    let scanRoot: Node
    @Binding var focusedNode: Node
    let maxRings: Int
    let minAngleDegrees: Double
    let onHoverChange: (HoverInfo?) -> Void

    struct HoverInfo {
        let node: Node
        let pctOfFocused: Double
        let pctOfTotal: Double
        let cursor: CGPoint
    }

    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outerRadius = dim * 0.46
            let innerRadius = max(36.0, outerRadius * 0.18)
            let ringWidth = (outerRadius - innerRadius) / Double(max(maxRings - 1, 1))
            let minAngleRad = minAngleDegrees * .pi / 180.0
            let layouts = WedgeGeometry.computeLayouts(focusedRoot: focusedNode, maxRings: maxRings, minAngle: minAngleRad)

            ZStack {
                Canvas { ctx, _ in
                    for layout in layouts where layout.ringIndex >= 1 {
                        let ringInner = innerRadius + ringWidth * Double(layout.ringIndex - 1)
                        let ringOuter = ringInner + ringWidth
                        let path = WedgeGeometry.annularWedgePath(
                            center: center,
                            innerRadius: ringInner,
                            outerRadius: ringOuter,
                            startAngle: layout.startAngle,
                            endAngle: layout.endAngle
                        )
                        ctx.fill(path, with: .color(WedgeGeometry.wedgeColor(for: layout)))
                        ctx.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 0.6)
                    }
                    let centerRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
                    let centerPath = Path(ellipseIn: centerRect)
                    ctx.stroke(centerPath, with: .color(.secondary.opacity(0.5)), lineWidth: 1)

                    let labelText = focusedNode.name
                    let label = Text(labelText).font(.system(size: 11, weight: .medium)).foregroundColor(Color(nsColor: .labelColor))
                    ctx.draw(label, at: CGPoint(x: center.x, y: center.y - 8))
                    let sizeText = Text(SizeFormatter.human(focusedNode.totalSize)).font(.system(size: 10)).foregroundColor(Color(nsColor: .secondaryLabelColor))
                    ctx.draw(sizeText, at: CGPoint(x: center.x, y: center.y + 8))
                }
                .contentShape(Rectangle())
                .onTapGesture { loc in
                    let hit = WedgeGeometry.hitTest(layouts: layouts, at: loc, center: center, innerRadius: innerRadius, ringWidth: ringWidth)
                    handleTap(hit)
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let loc):
                        let hit = WedgeGeometry.hitTest(layouts: layouts, at: loc, center: center, innerRadius: innerRadius, ringWidth: ringWidth)
                        if let hit {
                            let pctFocused = focusedNode.totalSize > 0 ? Double(hit.node.totalSize) / Double(focusedNode.totalSize) : 0
                            let pctTotal = scanRoot.totalSize > 0 ? Double(hit.node.totalSize) / Double(scanRoot.totalSize) : 0
                            onHoverChange(HoverInfo(node: hit.node, pctOfFocused: pctFocused, pctOfTotal: pctTotal, cursor: loc))
                        } else {
                            onHoverChange(nil)
                        }
                    case .ended:
                        onHoverChange(nil)
                    }
                }
            }
        }
    }

    private func handleTap(_ hit: WedgeLayout?) {
        guard let hit else { return }
        if hit.ringIndex == 0 {
            if let parent = focusedNode.parent {
                focusedNode = parent
            }
        } else if hit.node.isDirectory && !hit.node.children.isEmpty {
            focusedNode = hit.node
        }
    }
}
