# Numbra — QA Findings

Manual walkthrough on iPhone 17 Pro simulator (iOS 26.4), fresh Debug build.
Flow exercised end-to-end: Studio → New painting → paywall → free starter scene →
Difficulty → engine generation → Paint (tap-fill, mistake-proof, color switch, undo,
magic fill, zoom, fit, find-next) → 100% completion → Complete screen → Timelapse → Share.

No crashes observed. The captured stdout/stderr log was empty (app emits zero diagnostic logging).

Severity legend: 🔴 broken feature · 🟠 UX/correctness · 🟡 polish

---

## 🔴 1. Share button does nothing
The primary **Share** button on the share card is a no-op.

- `Sources/Screens/StudioExtras.swift:176` — action closure is empty:
  ```swift
  NButton(title: "Share", variant: .soft, size: .md, icon: "share", fullWidth: true) {}
  ```
- There is **no `UIActivityViewController` / `ShareLink` anywhere in `Sources/`** — share is entirely unimplemented.

Impact: completing a painting → Share → nothing happens. Broken core loop + lost virality.
(The adjacent "HD · Plus" button *is* wired to `onPaywall()`; only the free share path is dead.)

**Fix:** wire it to present a `UIActivityViewController` rendering the share-card image.

---

## 🔴 2. Timelapse replay is rendered upside-down
The timelapse plays the painting vertically flipped relative to the actual canvas.

- `Sources/Screens/StudioExtras.swift:135`:
  ```swift
  frame = UIImage(cgImage: out, scale: 1, orientation: .downMirrored)
  ```
  `.downMirrored` applies a vertical flip. The painted "after" image (`Painter.painted`,
  `Sources/Model/AppModel.swift:311`) builds an identical top-row-0 buffer and displays it
  upright with default `.up`.

**Fix:** change `.downMirrored` → `.up` (re-run timelapse to confirm orientation; watch the
baked-in seam overlay stays aligned).

---

## 🔴 3. Share card before/after images mismatch
The two panels ("Photo" / "Painted") show what look like different, unrelated images; the
"Painted" panel does not match the canvas that was actually painted.

- `Sources/Model/AppModel.swift:286`:
  ```swift
  let before = sampleById(activeId ?? "")?.thumb ?? sourceThumb
  ```
  "before" pulls the sample's stored **thumbnail**, which differs from the source image
  actually fed to the engine.
- `before` and `after` (`Painter.painted`) also have **different aspect ratios**, while
  `ShareCardView.frameCell` (`Sources/Screens/StudioExtras.swift:197`) uses
  `.aspectRatio(1, contentMode: .fill)` — so each cell square-crops to a different framing,
  making them look like two different pictures.

**Fix:** use the real source image used for generation as "before", and match the crop/aspect
of both cells so they show the same framing.

---

## 🟠 4. Continuing a painting forces the Difficulty modal
Tapping a started/in-progress image (to resume painting) brings up the **Difficulty selector**
modal, which makes no sense when you're continuing an existing canvas.

- There should be a direct **resume** into the canvas.
- There should also be a **Reset / Restart** action (to regenerate at a new difficulty or
  start the same canvas over), separate from resume.

---

## 🟠 5. Zoomed canvas paints behind the UI; panning is clamped at edges
- When zoomed, the **entire screen** is treated as canvas, so painted regions render *behind*
  the toolbar / palette / floating controls.
- Panning is **blocked at the canvas edges** — you can't move a corner/edge region out from
  under the UI.

**Wanted behavior:** free panning with generous overscroll — any corner (and beyond) should be
draggable to the center, so every region can be brought into a clear, unobstructed area.

---

## 🟠 6. "Paint" mode isn't true region brushing
The intended design is **two distinct modes**:
1. **Tap-to-fill** — fast, dopamine-driven, click a region → fills instantly.
2. **Brush** — calm, deliberate: user zooms in, locks onto a single region, and **swipes to
   color it in gradually** (monotonous, meditative stroke-painting of one region).

Current Paint mode does not deliver mode 2 (single-region swipe-to-fill with a locked region).
Needs a UX rethink: lock the active region, accumulate paint coverage along the stroke, only
count the piece complete once sufficiently covered.

---

## 🟠 7. Tiny regions are nearly untappable at fit-zoom
On Medium (196 pieces) many regions are < 12px; several are degenerate in the a11y tree —
`Region 68` reported bounds `0×0`, `Region 88` `3×1`, `Region 67` `1×5`. At fit-zoom a tap
routinely lands on a neighbor and (correctly) does nothing under the mistake-proof rule, which
reads as "the app ignored me." Needed zoom-in before small regions filled reliably.

**Fix ideas:** tap tolerance / snap-to-nearest-region-of-selected-color; engine small-region
merge pass should eliminate 1px slivers; investigate the `0×0` region (engine emitting an
unusable region).

---

## 🟡 8. "New painting" tile breaks the library grid
- Renders as a short dashed pill (~176×79) while every other library card is a full-height
  image card (~176×217). It floats mid-row, **misaligned** with the tall "Starry Night" card
  beside it, leaving a large empty gap below it before "The Great Wave."
- Dashed outline + filled "+" circle style is inconsistent with the solid image cards.

**Fix:** make it a full-height card matching the sibling card footprint, top-aligned.

---

## 🟡 9. Selected-color frame radius doesn't match the swatch
The selected-color highlight frame's corner radius doesn't match the color button's border
radius, so the selection ring looks misfit around the swatch.

---

## 🟡 10. Completed painting still labeled "CONTINUE"
Studio featured card shows `CONTINUE · Starry Night · 100%`. A 100%-complete canvas labeled
"Continue" is confusing — should read "View" / "Done" / "Replay".

---

## 🟡 11. Library header collides with the status bar
When the Library is scrolled up, the **"Library / 6 canvases" header overlaps the status bar**
("Library" over the clock, "6 canvases" over the Wi-Fi/battery icons). Scroll content isn't
insetting below the safe area.

---

## 🟡 12. Share card overlay doesn't fully dim the screen behind it
The Complete screen's own Share/Studio/Close buttons bleed through underneath the share-card
overlay. The card has a 0.6 scrim but the Complete buttons sit above it in z-order.

---

## 🟡 13. Accessibility/perf: every region is an individual a11y element
The paint screen exposes all regions (196 on Medium, ~130 on Hard) as individual
`Region N, color M` buttons. VoiceOver users must swipe through every region; automation UI
queries also took 10–12s. Consider grouping or a custom canvas a11y model.

---

## ✅ Verified working
- Engine generation (Medium → 196 regions, palette numbered light→dark, ~1.6s).
- Paywall bottom sheet — correctly gates Upload photo, Take photo, Hard difficulty; "Maybe later" dismisses.
- Mistake-proof fill (wrong color → no fill).
- Color switch, Undo, Magic fill (completes the selected color), Zoom in/out, Fit-to-screen, Find-next-piece.
- Complete screen (time / pieces / XP, achievement unlock); streak flame incremented on completion.
- Per-color remaining counts and palette completion checkmarks.

## Note (not a bug)
App emits zero stdout/stderr — no diagnostic logging at all. Consider a lightweight `os.Logger`
on the engine and paint paths for field debugging.
