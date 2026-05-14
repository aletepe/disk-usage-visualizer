# Backlog

## Dark mode support

Right now the chart area follows the system color scheme, but the wedge colors
(HSB hash-based, brightness 0.55–0.92) and the stroke (`.black.opacity(0.18)`)
were originally tuned for a dark background. In light mode they're fine; in
dark mode the high-brightness outer rings may look washed out and the dark
stroke vanishes.

Tasks:
- Detect color scheme via `@Environment(\.colorScheme)` in `SunburstView`.
- Adjust `WedgeGeometry.wedgeColor(for:ring:)` to dim brightness in dark mode.
- Switch the wedge stroke to `.primary.opacity(0.18)` (auto-adapting) or pick
  per-scheme strokes.
- Verify `TooltipOverlay` `.regularMaterial` background reads in both schemes
  (should already, but confirm).
- Add a manual "Appearance" toggle in the toolbar (System / Light / Dark) bound
  to `.preferredColorScheme(...)` if a forced theme is desired.
