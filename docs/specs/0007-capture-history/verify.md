# Verify: Capture history · spec 0007 · updated 2026-10-28
_Steps derived from spec 0007 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._
The history file is `~/Library/Application Support/<bundle id>/history.json`. Run the Debug build from Xcode (it uses its own bundle id, so its own folder).

## UI / manual
- [ ] Capture text from a window, open the menu bar icon → Recent → one new line with the first line of that text → AC-1, AC-4
- [ ] Capture a blank area ("No text found") → Recent gets no new line → AC-1
- [ ] Capture 21 different texts → Recent lists 20, newest first, the first one is gone → AC-2
- [ ] Capture the same text twice, with another capture between → one line, now at the top → AC-3
- [ ] Capture text starting with blank lines and tabs, and a line over 40 characters → label skips blanks, spaces collapsed, cut at 40 with "…" → AC-4
- [ ] Empty history (fresh folder) → Recent shows a greyed "No captures yet" and Clear History is greyed → AC-4, AC-6
- [ ] Pick an older line, paste into TextEdit → full text pasted, notice "Copied N characters" at top center of the display under the mouse, with the sound; the line moves to the top → AC-5 (Value sourcing: notice count, position)
- [ ] Pick while a slow capture is still reading → the capture still finishes and copies → AC-5
- [ ] Capture a very long text (more than 10,000 characters, for example a long page) → clipboard has all of it; picking the entry says "(shortened)" → AC-8
- [ ] Click Clear History → list is "No captures yet" at once, no confirmation → AC-6
- [ ] Quit and reopen Screencopy → the same lines in the same order come back → AC-7
- [ ] Capture again within a second of launching the app → the capture is still in Recent, and older saved lines are still there too → AC-12
- [ ] Capture with the network switched off → works the same → AC-13

## Commands
- [ ] `stat -f '%Lp' ~/Library/Application\ Support/<bundle id>` → `700`; `stat -f '%Lp' …/history.json` → `600`, also after a second capture → AC-9
- [ ] `tmutil isexcluded ~/Library/Application\ Support/<bundle id>` → `[Excluded]` → AC-9
- [ ] Quit the app, put `garbage` in `history.json`, launch → empty history, `history.json.bak` exists with mode 600, `history.json` rewritten on next capture → AC-10
- [ ] Click Clear History, then `cat history.json` and `ls` the folder → `{"entries":[],"version":1}`, no `.bak`, no leftover `.tmp-` file → AC-6, AC-11
- [ ] `log show --last 5m --predicate 'subsystem == "com.norbertoignacio.screencopy" && category == "history"'` after the steps above → lines hold error types only, no captured text, no counts, no ids → AC-13
- [ ] `grep -rnE 'URLSession|URLRequest|NWConnection' ScreencopyKit/Sources/ScreencopyHistory Screencopy/HistoryModel.swift` → no matches → AC-13
- [ ] `cd ScreencopyKit && swift test` → all pass (rules, labels, store, pipeline hook) → AC-1 to AC-3, AC-7 to AC-11

## Acceptance-criteria coverage
- AC-1 … Recent after capture, blank capture, pipeline tests · AC-2 … 21 captures, rules tests · AC-3 … repeat capture, rules tests
- AC-4 … label cases, empty state · AC-5 … pick, notice, slow capture · AC-6 … Clear History, file contents
- AC-7 … relaunch, store test · AC-8 … long text, rules test · AC-9 … stat, tmutil, store tests
- AC-10 … garbage file, store tests · AC-11 … file contents, temp file, failed save test · AC-12 … launch race (manual), model not unit tested
- AC-13 … log show, grep, offline capture
