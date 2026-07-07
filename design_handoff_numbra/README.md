# Handoff: Numbra — Paint-by-Numbers Mobile App

## Overview
Numbra is a mobile (iOS-first) app that turns any image into a paint-by-numbers
canvas. The user picks a photo (or a built-in "master painting" sample), chooses a
difficulty, and the app generates a numbered, paintable canvas. They color it in by
tapping regions or dragging to paint, with progress tracking, hints, undo, a magic
fill, sound/ambience, a timelapse replay, XP/levels/streaks/achievements, a daily
challenge, themed packs, and a Plus paywall. There is a first-launch onboarding flow
and an in-canvas tutorial.

The aesthetic is a deliberate "art gallery / Post-Impressionist" direction:
lavender-grey gallery walls, a vermilion accent with viridian/gold/ultramarine
secondaries, Bodoni Moda display type, Space Grotesk UI type, and homages to famous
paintings (Van Gogh's *Starry Night*, Hokusai's *Great Wave*, Matisse cut-outs).

## About the Design Files
The files in this bundle are **design references created in HTML/React (via in-browser
Babel)** — a working prototype showing the intended look and behavior. They are **not
production code to ship directly.** The task is to **recreate this experience in the
target codebase's environment** (e.g. React Native / Expo, SwiftUI, Flutter) using its
established patterns, navigation, and component libraries. If no environment exists
yet, choose the most appropriate mobile framework and implement there.

The one part that is genuinely reusable as *logic* (not styling) is the
**paint-by-numbers engine** (`pbn-engine.jsx`) and the **canvas interaction model**
(`pbn-canvas.jsx`). The algorithms — color quantization, region segmentation, hit
testing, fill/undo — should be ported faithfully; only the rendering layer changes per
platform.

## Fidelity
**High-fidelity.** Final colors, typography, spacing, motion, and interactions are all
specified. Recreate the UI pixel-faithfully using the target codebase's libraries.
Exact tokens are listed in **Design Tokens** below.

---

## Core Concept: The Paint-by-Numbers Engine
This is the heart of the product. Implemented in `pbn-engine.jsx`, `generate(src, opts)`
turns an image into paintable data. Pipeline:

1. **Downscale** the source image to a working buffer whose long side = `opts.detail`
   px (Easy 66, Medium 96, Hard 132). Smaller = bigger, fewer regions.
2. **Median-cut color quantization** to `opts.colors` colors (Easy 10, Medium 16,
   Hard 24).
3. **Nearest-palette mapping** of every pixel → index map.
4. **3×3 majority smoothing** to remove single-pixel speckle.
5. **Connected-component labeling** (4-connectivity, iterative stack) → regions.
6. **Small-region merging**: regions below `minSize` (≈ detail²/2600) are merged into
   their dominant neighbor (most shared border). Two passes.
7. **Palette sorted light→dark**, regions renumbered accordingly.
8. **Per-region outputs**: color index, centroid (nearest interior pixel to the mean,
   so the number sits inside the shape), an inscribed-radius hint `r` (for label font
   sizing & cull), and a **boundary segment list** (Float32Array of x1,y1,x2,y2 edges
   between differing labels) for drawing seams.

`generate()` returns:
```
{
  w, h,                 // working buffer dimensions
  palette: [{ r,g,b, hex, light:bool, num:1..N }],
  colorCounts: Int32Array,   // # regions per palette color
  labels: Int32Array(w*h),   // region id per pixel — used for hit testing
  regionColor: Int32Array,   // palette index per region
  regionPixels: [[pixelIndex,...]],  // pixels per region (for fills)
  regionCount,
  centroids: [{ x, y, r }],  // label anchor + size hint, in image coords
  segments: Float32Array,    // boundary edges for seam stroking
}
```

`makeSample(name, size)` procedurally draws demo "photos" on a canvas (so the app
needs no external assets): `sunset, lake, bloom, balloon, starry` (Starry Night),
`wave` (Great Wave). A `addTexture()` multi-octave sine pass roughens flat fills so
quantization yields satisfying region counts. **In production these are replaced by
real user photos and a curated art library** — keep the engine, drop the procedural
samples (or keep 1–2 as free starters).

### Hit testing & rendering model (`pbn-canvas.jsx`)
- The canvas keeps three offscreen buffers at image resolution: **fill** (paper color,
  painted regions written in over time), **highlight** (selected-color unpainted
  regions), and the **boundary Path2D**.
- A transform `{ scale, tx, ty }` maps image→screen. **Hit testing** is O(1):
  `labels[iy*w + ix]` at the transformed pointer location gives the region id.
- **Fill** writes a region's pixels into the fill buffer and clears them from the
  highlight buffer. **Undo** pops the fill-order stack and repaints those pixels back
  to paper. Fill order is also what drives the **timelapse**.
- Redraw is scheduled via `requestAnimationFrame` **with a `setTimeout(45ms)` fallback**
  — important, because rAF is throttled in background/offscreen contexts and the
  fallback guarantees a paint. Port this resilience.

---

## Screens / Views

### 1. Onboarding (`onboarding.jsx`) — first launch only
- **Purpose**: Introduce the app with three full-screen slides, each with a painting
  motif (hand-built SVG homages: Starry Night swirl, Great Wave, Matisse cut-outs).
- **Layout**: Top ~52% is the motif "stage" (min-height 360px) with a colored
  background that crossfades between slides; bottom is copy. Slides crossfade
  (opacity .5s, scale 1→1.06 .6s).
- **Components**:
  - Skip pill — top-right, `rgba(255,255,255,0.16)` bg, white text, 13.5px/600,
    padding 7×14, radius 999.
  - Kicker — uppercase, 13px/700, letter-spacing .16em, `rgba(255,255,255,0.65)`.
  - Title — Bodoni Moda 44px/500, line-height 1.02, white, `white-space: pre-line`
    (uses `\n`), letter-spacing -.01em.
  - Body — Space Grotesk 16px/1.5, `rgba(255,255,255,0.82)`, max-width 320.
  - Dot indicators — active 26×8, inactive 8×8, radius 99, white / `rgba(255,255,255,0.32)`.
  - CTA — full-width white button, text colored to the slide bg, 17px/700, radius 999,
    padding 17×24, right-arrow icon; label "Continue" then "Start painting".
- **Slide backgrounds**: `#162a63` (Starry), `#1f4f78` (Wave), `#1E8A78` (Matisse).
- **Persistence**: sets `localStorage.numbra_onboarded = '1'` on finish/skip.

### 2. Gallery / Studio (`screens.jsx` → `Gallery`)
- **Purpose**: Home. Continue in-progress work, start new, see daily challenge,
  packs, library, level.
- **Layout** (vertical scroll, `--paper` bg):
  - Header (padding 70/22/8): left = "NUMBRA" terra kicker (13px/700, .14em upper) +
    "Your studio" Bodoni 38px/400 (nowrap); right = `LevelBadge` (48px progress ring
    with level number).
  - `DailyBanner` (`studio-extras.jsx`): `--ink` card, 70px rounded thumbnail (greened
    check overlay if done), "DAILY CHALLENGE" terra kicker + flame streak count,
    Bodoni 20px title, terra "Start" pill (or ✓ when done).
  - Featured/continue card: margin 18, radius 28, aspect 3/2, image with bottom
    gradient, "Continue"/"Featured" label + Bodoni 27px title + progress ring w/ %.
  - `PacksRail`: horizontal scroller of 150×100 pack cards (two-image split cover,
    bottom gradient, PLUS lock badge if `plus`), title + "{n} scenes".
  - Library grid (2-col, gap 14): a dashed "New painting" tile (terra plus FAB) plus
    project tiles (1:1, radius 24). Completed → green check chip top-right; in-progress
    → white progress bar bottom. Caption: title + "{%} done" / "Completed" / "{n} colors".

### 3. Upload / New Painting (`screens.jsx` → `UploadScreen`)
- **Purpose**: Choose an image source. **Custom photo upload is Plus-gated.**
- **Layout**: Back button + "New painting" Bodoni 28px. Two source buttons:
  - "Upload photo" — `--ink` card. "Take photo" — `--card` with border.
  - **When not Plus**: each shows a `PLUS` lock badge (terra pill, top-right) and tapping
    calls `onPaywall()` instead of opening the file picker. A terra info strip explains
    "Turning your own photos into canvases is a Numbra Plus feature."
  - When Plus: tapping opens a hidden `<input type="file" accept="image/*">`.
- **Free starter scenes**: 2-col grid of sample tiles (1:1, selectable, 2.5px terra
  border when chosen, name in bottom gradient).
- **Sticky footer CTA**: primary "Use "{title}"" (disabled until a pick), calls `onPick`.

### 4. Difficulty (`screens.jsx` → `DifficultyScreen`)
- **Purpose**: Pick Easy / Medium / Hard. **Hard is Plus-gated.**
- **Layout**: Back + "Difficulty" Bodoni 28px. 16:10 preview of chosen image.
  Three selectable rows (radio-card pattern): a bar-graph difficulty glyph, label +
  subtitle, right-aligned "{colors} colors" + "{pieces} pieces". Selected = 2.5px terra
  border + soft terra shadow. Hard row shows a PLUS badge when not Plus.
- **DIFFS config**: Easy {colors:10, detail:66, "~50 pieces"}, Medium {16, 96, "~80"},
  Hard {24, 132, "~130"}.
- **CTA**: "Create canvas" — but if `(picked.custom || diff==='hard') && !isPlus` it
  reads "Unlock & create canvas" and opens the paywall, passing the chosen config so it
  can resume after purchase.

### 5. Processing (`screens.jsx` → `ProcessingScreen`)
- **Purpose**: Cover the ~720ms engine run with a branded loader.
- **Layout**: Centered 220×220 rounded image with a diagonal sheen sweep
  (`@keyframes sheen`, 1.3s linear infinite). Bodoni 24px label ("Transforming" for
  custom, "Building canvas" for samples). A 4-step checklist that advances every 520ms:
  "Reading your image → Choosing a palette → Tracing regions → Numbering pieces."

### 6. Paint (the core experience — `paint-screen.jsx` + `pbn-canvas.jsx`)
- **Purpose**: Color the canvas.
- **Layout**:
  - **Top bar** (gradient from `canvasBg`): back, progress bar + "{pct}% · {done}/{total}
    pieces", **Undo** (disabled when nothing to undo), **Hint/target** (flies to nearest
    unpainted piece of the selected color).
  - **Canvas** fills the screen. Pinch / drag / double-tap to zoom & pan; regions move
    with the image. Vector seams; numbers scale with zoom and cull when too small or
    off-screen. Satisfying white ring pulse on fill; red X flash + shake + haptic on a
    wrong placement (mistake-proof: wrong color never fills).
  - **Minimap** (`paint-extras.jsx`): top-left, appears only when zoomed in
    (`scale > fit*1.12`); shows source thumb + a viewport rectangle.
  - **Right rail**: zoom +, zoom −, fit, and a sound/ambience toggle (sage when on).
  - **Bottom dock** (gradient): a Tap/Paint `Segmented` control + a sage **magic-fill**
    button (auto-fills all remaining pieces of the current color, staggered). Below, a
    horizontally-scrolling **palette rail**: 52×52 swatches with the color number (or a
    check when finished), remaining-count beneath, selected swatch lifts 6px and gets a
    double ring. Finished colors dim to 0.4. **Auto-advances** to the next unfinished
    color when one completes.
  - **Tutorial overlay** (`paint-extras.jsx`, first canvas only): 4 spotlight coach-marks
    (welcome, palette, two modes, magic & hints). Sets `localStorage.numbra_tut='1'`.
- **Two coloring modes**:
  - **Tap**: tap a region → fills iff its color == selected color, else wrong-feedback.
    Double-tap also zooms.
  - **Paint**: drag a finger; every region crossed fills if it matches the selected
    color (each region considered once per stroke). Two-finger gesture always = pan/zoom.
- **Sound** (`fx.jsx`): WebAudio. Per-fill warm pentatonic pluck (pitch varies by color),
  magic = arpeggio, complete = chord, plus an optional ambient pad. Off by default
  (autoplay rules); toggled in-canvas; preference in `localStorage.numbra_sound`.
  Haptics via `navigator.vibrate`.

### 7. Complete (`screens.jsx` → `CompleteScreen`)
- **Purpose**: Celebrate + share.
- **Layout**: "MASTERPIECE COMPLETE" terra kicker, Bodoni 34px title, the finished
  rendered painting in a white frame, rotated -1.5° with a `popIn` scale animation +
  `Confetti` (`fx.jsx`, canvas particle burst). Stats row: Time, Pieces, XP. CTAs:
  primary "Watch timelapse", then "Share" + "Studio".

### 8. Overlays
- **TimelapsePlayer** (`studio-extras.jsx`): full-screen dark player that replays fills
  in recorded order onto a paper canvas. Scrubber, play/restart, 1×–4× speed. Renders
  by re-filling up to index N each frame.
- **ShareCard** (`studio-extras.jsx`): before/after card (Photo → Painted) on `--ink`,
  branded, with stats. "Save HD" is Plus-gated.
- **AchievementsSheet** (`studio-extras.jsx`): bottom sheet — level ring + XP-to-next +
  streak flame, then a 2-col grid of 9 achievements (locked ones dimmed with a lock icon).
- **Pack sheet** (`app.jsx`): bottom sheet listing a pack's scenes; premium packs open
  the paywall instead when not Plus.
- **Paywall sheet** (`app.jsx`): "Numbra Plus" — sparkle badge, 3 benefit rows, primary
  "Start free trial · then $4.99/mo", "Maybe later". On purchase sets `isPlus=true` and,
  if a difficulty config was pending, resumes canvas creation.
- **Toast** (`paint-extras.jsx`): top pill for "+XP", "Level N reached", and achievement
  unlocks.

---

## Interactions & Behavior
- **Navigation** is a simple screen state machine in `app.jsx` (`screen` ∈ gallery,
  upload, difficulty, processing, paint, complete) plus overlay/sheet booleans. Port to
  the target's navigation stack.
- **Gestures**: single-pointer = pan (Tap mode) or paint (Paint mode); two-pointer =
  pinch-zoom about the midpoint; wheel = zoom (desktop); double-tap = zoom toggle.
  Clamp scale to `[fit*0.85, max(fit*6,16)]`; keep the image overlapping the viewport.
- **Hint**: tween scale/translate to center the nearest unfilled region of the selected
  color; pulse it.
- **Magic fill**: collect all unfilled regions of the selected color, fill in staggered
  batches (~28ms) for a sweep effect.
- **Auto-advance**: when the selected color hits 0 remaining, select the next color that
  still has pieces.
- **Animations**: onboarding crossfades (.5–.6s); processing sheen (1.3s loop) &
  checklist (520ms steps); fill ring pulse (460ms); wrong-shake (`shakeX` .34s); complete
  `popIn` (scale, ~.7s) + confetti (~2.6s); sheets slide (`cubic-bezier(.22,1,.36,1)`
  .42s); toast (.35s).
- **Reduced motion / capture safety**: base styles must show the end state; never leave
  content at `opacity:0` waiting on a JS/CSS animation that may not run. (The complete
  card animates scale only, not opacity, for this reason.)

## State Management
Per-app (in `app.jsx`):
- `screen`, `picked` ({src,title,custom,id,isDaily}), `data` (engine output),
  `initialFilled` (restore), `sourceThumb`, `activeId`.
- `isPlus`, `paywall` (pending config | 'generic').
- `complete` ({img, before, time, pieces, xp, data, order}), `overlay`
  ({kind:'timelapse'|'share', ...}), `achOpen`, `packSheet`, `toast`.
- `progress` (from `progression.jsx`), `tutSeen`, `onboarded`.
- `projects[]`: each {id, title, src, thumb, colors, progress, session}. `session`
  holds {data, filled, order, elapsed, isHard} so work resumes and the completed view
  can replay.

Per-canvas (in `pbn-canvas.jsx`, kept in a mutable ref — not React state, for perf):
filled mask, per-color filled counts, fill-order stack, mistake count, transform,
buffers. Exposes imperative methods: `hint, magicFill, undo, zoomBy, fitView, getState`.

### Progression (`progression.jsx`, localStorage `numbra_progress_v1`)
- Tracks xp, completed, totalPieces, perfectRuns, streak/maxStreak, lastPlayDay,
  dailyDoneDay, customMade, hardDone, unlocked{}.
- `levelFor(xp)`: level N needs `120*N` xp.
- `play()` maintains streak continuity by calendar day; `touchOpen()` resets a broken
  streak on launch.
- `recordCompletion({pieces,mistakes,isCustom,isHard,isDaily})` awards
  `50 + min(70,pieces) + (mistakes===0?30:0) + (isDaily?25:0)` xp, updates counters,
  unlocks achievements, returns {xpGain, leveledUp, level, newly[], progress}.
- `dailyIndex(n)` is a deterministic per-date pick (hash of YYYYMMDD).
- **9 achievements**: First Strokes, Flawless, Collector (5), Marathon (1000 pieces),
  On a Roll (3-day), Devoted (7-day), Rising Artist (lvl 5), Alchemist (transform a
  photo), Master Hand (finish Hard).

### Other persisted keys
`numbra_onboarded`, `numbra_tut`, `numbra_sound`. (The Tweaks panel's Demo section
clears these to replay onboarding/tutorial or reset progress — that's a dev affordance,
not a shipping feature.)

## Design Tokens
CSS custom properties (defined in `Numbra.html` `:root`):
```
--paper   #E7E3EF   app background ("gallery wall", pale lavender-grey)
--ink     #221B33   deep ink-aubergine (text, dark cards)
--muted   #786F8C   secondary text
--terra   #E0492F   PRIMARY ACCENT — vermilion (also the Tweakable accent)
--sage    #1E8A78   viridian (success, magic-fill, "on" states)
--gold    #E0A52E   ochre gold
--ultra   #2746C9   ultramarine
--card    #FBFAFE   light surface
--card-2  #E1DCEC   muted surface / track
--line    rgba(34,27,51,0.10)  hairline borders
```
Canvas paint surface ("paper") default `#F4EEDF`; dark chrome bg `#16130f`.
Onboarding slide bgs `#162a63 / #1f4f78 / #1E8A78`.

**Accent options** (Tweakable): `#E0492F #2746C9 #1E8A78 #E0A52E #6E3F86`.
**Paper options**: `#F4EEDF #FBFAF4 #EFE7D6 #ECE9E2`.

Typography:
```
--display  'Bodoni Moda' (Google Fonts; opsz 6..96; weights 400/500/600 + italic 500)
           Used for all titles/headlines. Dramatic high-contrast didone.
--ui       'Space Grotesk' (Google Fonts; 400/500/600/700) Used for all UI/body.
```
Type scale in use (px): display 44 (onboarding), 38 (gallery h1), 34 (complete),
28 (screen titles), 27/26/24/23/22/20 (cards/sheets); UI 11.5–17, weights 600–800,
letter-spacing tightened ~-.01em on large display, widened .1–.16em on uppercase
kickers.

Radii: pills 999; cards 22–28; swatches/inputs 14–16; chips/badges 10–14.
Shadows: card `0 8–14px 20–34px rgba(60,40,25,.1–.16)` (retune to the aubergine ink in
production, e.g. `rgba(34,27,51,…)`); accent glow `0 6px 18px rgba(224,73,47,.34)`;
sage glow `0 6px 18px rgba(30,138,120,.32)`.
Spacing: screen gutters 18–22; control gaps 8–14; touch targets ≥ 44px.

Icons: a single inline-SVG set in `ui-kit.jsx` (`Icon` component, 24×24 viewBox,
`stroke="currentColor"`, round caps/joins). Reuse names or map to the codebase's icon lib.

## Assets
**None external.** All imagery is procedurally drawn (engine samples + onboarding SVG
motifs) and all icons are inline SVG. Fonts load from Google Fonts (Bodoni Moda, Space
Grotesk). In production, supply: a real curated art/sample library, and replace the
procedural `makeSample` scenes. The famous-painting motifs are original hand-built
homages (geometry/color references), not reproductions of copyrighted images.

## Files (in this bundle)
Design reference (HTML/React-in-Babel):
- `Numbra.html` — entry: fonts, `:root` tokens, keyframes, script load order.
- `app.jsx` — navigation, state, samples/packs config, paywall, sheets, Tweaks.
- `onboarding.jsx` — first-launch onboarding + painting-motif SVGs.
- `screens.jsx` — Gallery, UploadScreen, DifficultyScreen, ProcessingScreen,
  CompleteScreen (+ DIFFS config).
- `paint-screen.jsx` — the paint UI shell (top bar, dock, palette rail, modes, sound).
- `pbn-canvas.jsx` — interactive canvas: buffers, transform, gestures, fill/undo,
  hint/magic, draw loop. **(port the logic)**
- `pbn-engine.jsx` — the paint-by-numbers generation engine + procedural samples.
  **(port the logic)**
- `paint-extras.jsx` — Minimap, TutorialOverlay, Toast.
- `studio-extras.jsx` — TimelapsePlayer, ShareCard, AchievementsSheet, LevelBadge,
  DailyBanner, PacksRail.
- `progression.jsx` — XP/levels/streaks/achievements (localStorage).
- `fx.jsx` — WebAudio sound/ambience/haptics + Confetti.
- `ui-kit.jsx` — Icon set, Btn, Ring, Sheet, Segmented atoms.

Infrastructure (do not port; framework scaffolding):
- `ios-frame.jsx` — preview-only iPhone bezel.
- `tweaks-panel.jsx` — preview-only live-tweak panel.

## Implementation Notes for the Target Codebase
- **Engine first.** Port `pbn-engine.js` and the canvas fill/hit-test/undo model as
  pure logic + a platform draw layer (Skia/Canvas/Metal). Everything else is UI you can
  rebuild with native components.
- Keep canvas state **out of the reactive store** (use refs/equivalent) and drive
  rendering imperatively — re-rendering per fill will not perform.
- Preserve the **rAF + timeout fallback** redraw scheduler.
- Custom-photo upload and Hard mode and premium packs and HD export are **paywall gates**;
  wire them to the real IAP/entitlement system.
- Respect reduced-motion and never gate content visibility on an animation's start frame.
