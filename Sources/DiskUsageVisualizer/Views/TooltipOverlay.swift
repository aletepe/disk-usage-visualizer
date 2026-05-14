import SwiftUI

struct TooltipOverlay: View {
    let info: SunburstView.HoverInfo
    let containerSize: CGSize

    var body: some View {
        let tip = VStack(alignment: .leading, spacing: 3) {
            Text(info.node.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text(info.node.path)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                Text(SizeFormatter.human(info.node.totalSize))
                    .font(.system(size: 11, weight: .medium))
                Text("\(String(format: "%.1f", info.pctOfFocused * 100))% focus · \(String(format: "%.1f", info.pctOfTotal * 100))% total")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15))
        )
        .frame(maxWidth: 320, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

        let pos = clampPosition(info.cursor, container: containerSize)
        return tip.position(pos)
    }

    private func clampPosition(_ cursor: CGPoint, container: CGSize) -> CGPoint {
        let pad: CGFloat = 16
        let estW: CGFloat = 250
        let estH: CGFloat = 70
        var x = cursor.x + estW / 2 + pad
        var y = cursor.y - estH / 2 - pad
        if x + estW / 2 > container.width { x = cursor.x - estW / 2 - pad }
        if y - estH / 2 < 0 { y = cursor.y + estH / 2 + pad }
        x = min(max(x, estW / 2 + 4), container.width - estW / 2 - 4)
        y = min(max(y, estH / 2 + 4), container.height - estH / 2 - 4)
        return CGPoint(x: x, y: y)
    }
}
