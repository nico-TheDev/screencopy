# Verify: Region capture · spec 0003 · updated 2026-10-28
_Steps derived from spec 0003 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._
Run the Debug build from Xcode. In Debug, a released box opens a preview window showing the handed over image at box size.

## UI / manual
- [ ] Press Option+Shift+2 in Safari, then in a full screen app on another Space → dimmed still picture on every display within about 0.5 s, the source app stays active → AC-1
- [ ] Drag in all four directions → box is clear, stays inside the display; other displays stay dimmed → AC-2
- [ ] Release the mouse → overlay closes on all displays, preview window shows one image → AC-3
- [ ] Compare preview size with the readout: Retina, non Retina, and second display → width × height within 1 px of box × scale, content matches → AC-4 (Value sourcing: scale and pixel rect)
- [ ] Drag over a spot with the hint text, readout, and a Screencopy window nearby → none appear in the preview → AC-5
- [ ] Press Esc → overlay closes, no preview → AC-6
- [ ] Right click → same as Esc → AC-7
- [ ] Click without dragging, then drag a box under 4 pt → overlay stays open → AC-8
- [ ] Press the hotkey while the overlay is open → nothing changes, no second overlay → AC-9
- [ ] While selecting → crosshair cursor, live "W × H px" readout, hint fades after about 3 s → AC-10
- [ ] Run `tccutil reset ScreenCapture com.norbertoignacio.screencopy`, relaunch, press the hotkey → no overlay, status window with the permission message and both buttons, no system prompt → AC-11 (Value sourcing: permission gate)
- [ ] Open the overlay, then switch Space, plug or unplug a display, press Cmd+Tab, or lock the screen → overlay closes, screen not left dimmed → AC-13
- [ ] Change the display scaled resolution, repeat a capture → size still matches box × scale → AC-4 (Value sourcing: scale from the snapshot)

## Commands
- [ ] `cd ScreencopyKit && swift test` → all crop math tests pass → AC-4
- [ ] `scripts/check` → lint clean, package builds with warnings as errors
- [ ] `grep -rnE "URLSession|write\(to|NSImage.*tiff|logger.*image" Screencopy ScreencopyKit/Sources` → no network or image writing, only sizes logged → AC-14

## Acceptance-criteria coverage
- AC-1 … step 1 · AC-2 … 2 · AC-3 … 3 · AC-4 … 4, 13, swift test · AC-5 … 5 · AC-6 … 6 · AC-7 … 7 · AC-8 … 8 · AC-9 … 9 · AC-10 … 10 · AC-11 … 11 · AC-12 … not covered by a manual step (needs a forced snapshot failure; try denying permission mid capture) · AC-13 … 12 · AC-14 … grep
