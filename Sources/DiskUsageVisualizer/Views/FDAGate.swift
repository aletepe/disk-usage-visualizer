import SwiftUI
import AppKit

struct FDAGate: View {
    let onDismiss: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Full Disk Access required")
                .font(.title3.weight(.semibold))
            Text("To scan the whole disk, this app needs Full Disk Access. macOS only allows you to grant this from System Settings.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Steps:")
                .font(.system(size: 12, weight: .medium))
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Click \"Open System Settings\" below.")
                Text("2. Drag the DiskUsageVisualizer app into the list, or click + to add it.")
                Text("3. Toggle it on. macOS may ask you to quit and relaunch.")
                Text("4. Click \"Try again\" once granted.")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            HStack {
                Button("Open System Settings") { openPrivacyPane() }
                    .keyboardShortcut(.defaultAction)
                Button("Try again") { onRetry() }
                Spacer()
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func openPrivacyPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
