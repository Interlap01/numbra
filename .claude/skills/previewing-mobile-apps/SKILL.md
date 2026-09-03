---
name: previewing-mobile-apps
description: Use when working on this mobile app and needing to see, drive, or verify its UI without a device or simulator. The mobai-dev CLI previews the app in a phone sized viewport, returns the screen as a semantic tree, taps, types and scrolls by label, screenshots, hot reloads after edits, mocks location, permissions, camera, network and auth, and repairs native only dependencies with preview adapters. Covers Flutter, React Native and SwiftUI. Needs a free MobAI account (MOBAI_API_KEY or `mobai-dev login`). Triggers on "preview", "run the app", "show me the screen", "tap", "type into", "screenshot", "mock", "scenario", "test the flow", "build the app", "mobai-dev", "AUTH_REQUIRED".
---

# Previewing mobile apps

`mobai-dev` gives this sandbox a phone shaped screen. It runs the app's real
code in a phone sized viewport, no device or simulator involved, and the same
verbs work whether the app is Flutter, React Native or SwiftUI.

The mental model, in order of importance:

1. **Read the tree, not pixels.** `preview inspect` returns every element with
   its type, label, value, flags and exact rectangle. "The button is disabled"
   is one JSON field. Screenshots are for layout judgement and for showing a
   human, never the primary read.
2. **One preview, many commands.** Start it once with `--detach`; every later
   command is a fast round trip against the running app, which keeps its state.
3. **Failures are instructions.** Every failure is one JSON envelope with a
   `code`, a `message` and usually a `suggestion` naming the exact next
   command. Read `code` first, never parse prose.

Pass `--json` to every call.

## First contact with a project

```bash
mobai-dev setup --framework flutter --json   # flutter | react-native (rn) | swiftui (ios)
```

`--framework` is required: you know what this project is, and setup prescribes
the environment for it rather than guessing from a checkout. Detection runs as a
cross check, so a `warnings` entry saying the tree looks like something else
means one of you is wrong; read it before going on.

The answer is a plan. `toolchains` lists every prerequisite for this framework
on this machine as `{name, present, version, install, note}`, ending with
`engine:<name>`, the preview engine itself. `ready` is true when all of them are
present. **Install everything that is not present, in the order given, running
the commands in its `install` field verbatim**, then run setup again to confirm
`ready`. Nothing previews before that. setup succeeds either way: a plan is
guidance, not a failure.

## The account

Previews run against a MobAI account. Free, but not optional: the engine is
handed its permission to run by `mobai-dev`, which gets it from the MobAI
service, so a machine with no credential previews nothing. `AUTH_REQUIRED` is
what that looks like.

Nobody needs the desktop app or a prior sign-up for this: signing in with an
email MobAI has not seen creates the account, free, with the same emailed
code. So when there is no credential, ask the person for their email and sign
in, and say that this also registers them if they are new.

Two ways to hold one, and either is enough:

```bash
export MOBAI_API_KEY=mobai_...        # a key from the app; best for CI
```

or sign in, which is two ordinary commands and no prompt:

```bash
mobai-dev login                                            # who am I, if anyone
mobai-dev login --email you@example.com                    # sends a 6 digit code
mobai-dev login --email you@example.com --code 123456      # verifies it
```

The code arrives by email, so ask the person you are working with for it and
run the second command. Nothing here needs a terminal or a browser. A stored
login is refreshed automatically afterwards; you do not sign in again per
preview.

The engine is installed like anything else in the list. It lands in
`~/.mobai/engines/<name>` and every later run finds it with no configuration:

```bash
mobai-dev engines install rn --json                   # download and set up
mobai-dev engines install rn --from <dir|.tar.gz>     # from a local copy
mobai-dev engines list --json                         # what is installed
```

A missing engine also shows up later as `PREVIEW_ENGINE_MISSING` on any preview,
with the install command in its `suggestion`. A `bootstrap` of `stale` in the
listing means dependencies changed; run the install again.

Read the `renderer` field of the install and setup output, not just `ready`.
`ready: yes` means a preview can run; only `renderer: paint host` means it
renders at full fidelity. `renderer: cairo (DEGRADED: ...)` means screenshots
ship with substitute fonts, no emoji and no CJK, and the line names the fix.
One of those fixes is a license gate (Apple's SF Pro font license): that
acceptance is the project owner's decision, not yours. Ask the human and
report the preview as degraded until they decide; never accept a license or
silently settle for the degraded default on their behalf.

## Choosing what to preview

`--entry` says WHAT to bring up. Without it each engine starts the app at its
own entry point, which is right for a small app and wrong for a real
repository.

```bash
mobai-dev preview run --detach --json                              # the app's own entry
mobai-dev preview run --detach --entry Sources/Screens/GalleryView.swift --json
mobai-dev preview run --detach --entry GalleryView --json          # SwiftUI: by view name
```

**SwiftUI previews ONE screen and the files it reaches from there**, not the
whole project. That is what makes a large app previewable at all: everything
the screen does not need is left out, including files that import things the
engine has no answer for. Point it at the file holding the screen. Given a
directory it reads the `.swift` files sitting directly inside it, so a
repository root usually holds no screen and is the wrong target.

A path is resolved against the project directory and has to exist; anything
else is taken as a view name. So `--entry Sources/Screens/GalleryView.swift`
and `--entry GalleryView` are both fine, and a typo in a path falls back to
being treated as a name rather than silently previewing something else.

On a SwiftUI project with no screen at its root, running without `--entry` is
refused outright with `PREVIEW_ENTRY_REQUIRED`, and `details.screens` carries
the files it found. Pick one from that list. It refuses rather than guessing
because the alternative, compiling outward from the project root, meets an
unsupported dependency, then the next one behind it, and never converges.

If a preview fails with `PREVIEW_UNSUPPORTED_MODULE` or a compile error in a
file you did not expect, the target is usually too broad: name the screen's
file rather than the project.

## The loop

```bash
mobai-dev preview run --detach --json                 # once
mobai-dev preview inspect --json                      # what is on screen
mobai-dev preview tap --label Continue --json
mobai-dev preview type --label Email --text a@b.com --json
mobai-dev preview scroll --direction down --amount 400 --json
# ...edit source...
mobai-dev preview reload --json                       # pick the edit up
mobai-dev preview inspect --json                      # confirm the change
mobai-dev preview screenshot --out /tmp/shot.png --json
mobai-dev preview stop --json                         # when done
```

Targets resolve by `--id`, then `--label`, then `--text-match`, then
`--point x,y` (logical points in the viewport, not pixels). Prefer labels:
coordinates break on every layout change. `TARGET_AMBIGUOUS` lists candidates
rather than guessing; make the target more specific.

Do NOT restart the preview after each edit; reload exists for that. Do NOT
screenshot to check logic; inspect the tree. Do NOT start a second preview for
the same project.

## Failure codes worth knowing

| code | it means | do |
|---|---|---|
| `PREVIEW_NOT_RUNNING` | no preview up | `preview run --detach` |
| `TARGET_NOT_FOUND` / `TARGET_AMBIGUOUS` | bad target | fix the target; candidates are listed |
| `ACTION_UNSUPPORTED` | this engine cannot do that | check `preview info` capabilities, do it another way |
| `PREVIEW_ENGINE_MISSING` | engine not installed | run the `suggestion` |
| `PREVIEW_ENTRY_REQUIRED` | SwiftUI, and no screen was named | pick one from `details.screens` and pass it as `--entry` |
| `AUTH_REQUIRED` | no MobAI account on this machine, or the stored login was rejected | set `MOBAI_API_KEY`, or `mobai-dev login`, which also creates the account (see [The account](#the-account)) |
| `PLAN_REQUIRED` | the account is signed in but its plan does not include this (published devices, simulators shared from CI) | `mobai-dev upgrade --plan monthly` prints a payment link; give it to the person, the upgrade applies on the next command |
| `ENGINE_NOT_PERMITTED` | the engine was started without its permission, which normally means it was run directly | start previews with `mobai-dev preview`, never by calling the engine binary |
| `PREVIEW_UNSUPPORTED_MODULE` | dependencies that cannot run in the preview. `modules` lists every one found at once | first check the target is the screen's file and not the project (see [Choosing what to preview](#choosing-what-to-preview)); if the screen really needs them, write the adapters in one go: [writing-preview-adapters.md](./writing-preview-adapters.md) |
| `PREVIEW_COMPILE_FAILED` | the source does not compile | `details.errors` carries the compiler's lines; fix what they name |
| `PREVIEW_APP_ERROR` | React Native: the app threw before rendering | `details.pageError` names the file and line; `details.bundlerError` the module that failed to transform |
| `PREVIEW_RESTART_REQUIRED` | Flutter: an adapter was added or removed after the engine started | `preview stop`, then `preview run` again |
| `PREVIEW_MOCK_UNSUPPORTED` | capability not held by this engine | `details` lists what it does hold |

## Mocking the world

The app's environment, location, permissions, what the camera returns, what
the network answers, who is signed in, is data, not devices. Set it at start
with a scenario file, or change one capability live with no reload:

```bash
mobai-dev preview run --detach --scenario scenarios/checkout.yaml --json
mobai-dev mock location '{"lat":52.52,"lng":13.405,"label":"Berlin"}' --json
mobai-dev mock permissions '{"camera":"denied"}' --json
mobai-dev mock appearance dark --json
mobai-dev preview mock-state --json                   # the world as it stands
```

A live mock keeps the app's state, which is the point: drive to a screen, then
flip the condition it should react to. `preview run --appearance dark` starts
in dark mode, and because appearance is a live mock you can screenshot a screen
in both themes without restarting the engine or driving back to it. Values are
the same shapes scenario sections use; pass objects, not bare words. Check
`capabilities.mocks` in `preview info` before writing a scenario. Full schema
and worked examples: [writing-scenarios.md](./writing-scenarios.md).

## When a dependency cannot run

A package that talks to real hardware cannot execute in a preview. The engine
refuses with `PREVIEW_UNSUPPORTED_MODULE` naming the module, the importing
file, and the exact path where an adapter goes. Write a small adapter in the
app's own language mapping the package's used surface onto the preview's
primitives, and the preview resumes. Never edit the app's production source
for this. Mechanics per framework: [writing-preview-adapters.md](./writing-preview-adapters.md).

## Framework differences

Read `preview info --json` for the engine's actual capabilities instead of
guessing. The differences that matter:

- **Flutter**: hot reload via `preview reload`, state kept. First run builds a
  host app and takes minutes; later runs are fast. The host follows the app:
  its assets and fonts, its lock file, its macOS build settings, a `main`
  that takes arguments. The app believes it runs on a phone
  (`defaultTargetPlatform` is iOS, or Android under an android profile), but
  `Platform.isMacOS` from dart:io still says the desktop, so an app that
  branches on dart:io takes its desktop path. A channel the app opens to its
  own native code (not a plugin) is answered from a preview entry at
  `.mobai/preview/flutter/preview_main.dart` with `PreviewChannels.stub`; the
  same entry is where anything the app needs before its `main` goes. An
  adapter added after the engine started answers `PREVIEW_RESTART_REQUIRED`
  on reload: restart the preview.
- **React Native**: edits apply on their own through Fast Refresh; `reload` is
  a full page reload and loses component state, so it is rarely wanted.
  expo-router file based routing is supported. The engine handles what Metro
  would: tsconfig and babel import aliases, `require()` and CommonJS in the
  app's files, JSX in `.js`, `process.env` with the `EXPO_PUBLIC_*` values
  from the `.env` files, the app's own `babel.config.js` on the app's files
  (babel-preset-expo, NativeWind, Tamagui's compiler, decorators, with a
  Metro caller on iOS), the worklets plugin, `.ios` and `.native` files when
  no web or plain file exists. Do not write shims for any of that. The app's
  own code sees `Platform.OS` as the phone; dependencies see the web, so a
  library takes the fallback that renders in a browser. A Babel config that
  cannot load is reported on stderr and the built-in transforms carry on.
  What is not there: a named export the app imports from a module that never
  defines it, which Metro leaves undefined and ESM refuses, so shim that
  module under `mocks/` at its aliased path. A
  mock applies to the app's own imports; a library importing the same
  package keeps the real one unless the mock's first lines carry
  `@mobai-deep`.
- **SwiftUI**: previews one screen and what it reaches, so `--entry` names
  the file holding that screen (see [Choosing what to
  preview](#choosing-what-to-preview)). `reload` recompiles and restarts behind the same port; the
  response carries `stateReset: true`, so re-drive to the screen under work
  after a reload. A failed edit answers `PREVIEW_BUILD_FAILED` and the old
  build keeps running. Sheets, alerts, confirmation dialogs, menus and
  context menus present for real: the presenter's controls carry `covered`
  and refuse taps while one is up, a `Menu` node opens on tap, a node under
  a context menu carries `longPress` and a `longPress` action opens it, and
  any button inside an alert, dialog or menu closes it after its action.
  Lists of any length lay out; there is no row ceiling. `import Charts` and
  `import MapKit` draw (marks from their data, a map with its markers and
  the scenario's location); do not write adapters for them. A row with
  `.swipeActions` is a `Row` node flagged `swipeActions`: a `swipe` action
  with that row as `target` opens the drawer, whose buttons are `Button`
  nodes; a full swipe runs the first action. `.searchable` puts a
  `TextField` flagged `search` in the navigation chrome; `type` into it
  runs the app's own filtering.

## What the preview cannot answer

Native rendering fidelity, real gestures and keyboards, camera hardware,
performance, and how the App Store build behaves. When the question changes to
one of those, say so and move to a simulator or device instead of trusting the
preview past its limits. For layout, state, flow, copy, and error states, the
preview is measured against real devices and is the fast path.
