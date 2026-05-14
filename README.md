# Disk Usage Visualizer

Native macOS app (Swift + SwiftUI) that scans a folder or full disk and renders an interactive sunburst chart of allocated sizes.

## Build

```bash
chmod +x build.sh
./build.sh
open build/DiskUsageVisualizer.app
```

Requires Swift 5.9+ and the Xcode command line tools.

## Dev iteration

```bash
swift run
```

Runs the binary directly (no .app bundle, no Dock icon, no FDA grant). Useful for fast iteration on `$HOME` scans.

## Full Disk Access

For "Scan whole disk", grant FDA to `build/DiskUsageVisualizer.app` in
**System Settings → Privacy & Security → Full Disk Access**. The app does not
itself need to be Sandboxed; the bundle is ad-hoc signed by `build.sh` so the
TCC grant persists across rebuilds (for the same path).

## Behavior

- Uses `URLResourceKey.totalFileAllocatedSizeKey` (matches `du` allocated
  bytes; sparse-file-aware).
- Skips symlinks. Does not cross volume boundaries.
- Deduplicates hardlinked files and APFS clones via
  `fileResourceIdentifierKey`.
- When scanning `/`, hard-skips: `/System`, `/private`, `/cores`, `/sbin`,
  `/Volumes`, `/.Spotlight-V100`, `/.fseventsd`, `/.DocumentRevisions-V100`,
  `/.TemporaryItems`, `/.Trashes`, `/.vol`, `/.file`.
- Top-level subtrees scan in parallel via `TaskGroup`; each subtree walks
  sequentially.

## UI

- **Choose folder…** opens NSOpenPanel.
- **Scan whole disk** scans `/` (requires FDA).
- **Depth** slider (2–12) caps how many sunburst rings render. Sizes deeper
  than the cap fold into the cap-level wedge.
- **Size filter** hides wedges below a given % of the focused root (default off). Sizes still count toward the parent; only rendering is suppressed.
- Click any wedge to re-root the chart there. Click the center to zoom out
  one level. Hover for size + %.
- Breadcrumb above the chart shows the current focus path; click any
  segment to zoom directly there.
