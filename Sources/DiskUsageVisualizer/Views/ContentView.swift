import SwiftUI
import AppKit

struct ContentView: View {
    @State private var selectedRoot: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var scanRoot: Node?
    @State private var focusedNode: Node?
    @State private var maxRings: Double = 6
    @State private var minSizePercent: Double = 0
    @State private var hoverInfo: SunburstView.HoverInfo?
    @State private var showFDAGate: Bool = false
    @State private var scanTask: Task<Void, Never>?
    @State private var progress = ScanProgress()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ZStack {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 720)
        .sheet(isPresented: $showFDAGate) {
            FDAGate(
                onDismiss: { showFDAGate = false },
                onRetry: {
                    if SystemPaths.canReadLibrary() {
                        showFDAGate = false
                        startScan(root: URL(fileURLWithPath: "/"))
                    }
                }
            )
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button("Choose folder…") { chooseFolder() }
                    .disabled(progress.isScanning)

                Button {
                    if SystemPaths.canReadLibrary() {
                        selectedRoot = URL(fileURLWithPath: "/")
                        startScan(root: selectedRoot)
                    } else {
                        showFDAGate = true
                    }
                } label: {
                    Label("Scan whole disk", systemImage: "internaldrive")
                }
                .disabled(progress.isScanning)

                Button {
                    startScan(root: selectedRoot)
                } label: {
                    Label(scanRoot == nil ? "Scan" : "Re-scan", systemImage: "arrow.clockwise")
                }
                .disabled(progress.isScanning)
                .keyboardShortcut("r", modifiers: .command)

                if progress.isScanning {
                    Button("Cancel") { scanTask?.cancel() }
                        .tint(.red)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Text("Currently scanning:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(selectedRoot.path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))

                Spacer(minLength: 12)

                sliderBlock(label: "Depth", value: $maxRings, range: 2...12, step: 1, valueFormat: "%.0f", boundsFormat: "%.0f", sliderWidth: 260)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 12)
                sliderBlock(label: "Size filter", value: $minSizePercent, range: 0...99, step: 5, valueFormat: "≥ %.0f%%", boundsFormat: "%.0f%%", sliderWidth: 260)
            }
        }
        .padding(10)
        .background(.bar)
    }

    private func sliderBlock(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, valueFormat: String, boundsFormat: String, sliderWidth: CGFloat = 130) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label).font(.footnote).foregroundColor(.secondary)
            VStack(spacing: 1) {
                Slider(value: value, in: range, step: step)
                    .frame(width: sliderWidth)
                HStack {
                    Text(String(format: boundsFormat, range.lowerBound))
                    Spacer()
                    Text(String(format: boundsFormat, range.upperBound))
                }
                .font(.system(size: 9).monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: sliderWidth)
            }
            Text(String(format: valueFormat, value.wrappedValue))
                .font(.footnote.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var content: some View {
        if progress.isScanning {
            scanningView
        } else if let root = scanRoot, let focused = focusedNode {
            VStack(spacing: 8) {
                breadcrumb(for: focused)
                GeometryReader { geo in
                    ZStack {
                        SunburstView(
                            scanRoot: root,
                            focusedNode: Binding(
                                get: { focused },
                                set: { focusedNode = $0 }
                            ),
                            maxRings: Int(maxRings),
                            minAngleDegrees: minSizePercent * 3.6,
                            onHoverChange: { hoverInfo = $0 }
                        )
                        if let info = hoverInfo {
                            TooltipOverlay(info: info, containerSize: geo.size)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        } else {
            placeholderView
        }
    }

    private func breadcrumb(for focused: Node) -> some View {
        var chain: [Node] = []
        var cur: Node? = focused
        while let n = cur { chain.append(n); cur = n.parent }
        chain.reverse()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(chain.enumerated()), id: \.element.id) { idx, n in
                    if idx > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    Button(n.name) { focusedNode = n }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: idx == chain.count - 1 ? .semibold : .regular))
                        .foregroundColor(idx == chain.count - 1 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
        }
    }

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Scanning…").font(.title3)
            Text("\(progress.filesScanned.formatted()) files · \(SizeFormatter.human(progress.bytesScanned))")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            Text(progress.currentPath)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 600)
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Pick a folder and click Scan").foregroundColor(.secondary)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            if let root = scanRoot {
                Label(SizeFormatter.human(root.totalSize), systemImage: "externaldrive")
                Label("\(progress.filesScanned.formatted()) files", systemImage: "doc")
                if let focused = focusedNode, focused !== root {
                    Label("focus: \(SizeFormatter.human(focused.totalSize)) (\(SizeFormatter.percent(focused.totalSize, of: root.totalSize)))", systemImage: "scope")
                }
            }
            Spacer()
            if let err = progress.error, err != "Cancelled" {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = selectedRoot
        if panel.runModal() == .OK, let url = panel.url {
            selectedRoot = url
            startScan(root: url)
        }
    }

    private func startScan(root: URL) {
        scanTask?.cancel()
        scanRoot = nil
        focusedNode = nil
        hoverInfo = nil
        let opts = ScanOptions(
            crossVolumes: false,
            dedupHardlinks: true,
            excludeRootSystemPaths: root.path == "/",
            followSymlinks: false
        )
        let scanner = Scanner(options: opts, progress: progress)
        let progressRef = progress
        scanTask = Task { @MainActor in
            do {
                let result = try await scanner.scan(root: root)
                self.scanRoot = result
                self.focusedNode = result
            } catch is CancellationError {
                progressRef.finish(error: "Cancelled")
            } catch {
                progressRef.finish(error: error.localizedDescription)
            }
        }
    }
}
