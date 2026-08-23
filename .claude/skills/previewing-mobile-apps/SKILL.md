---
name: previewing-mobile-apps
description: Use when working on this mobile app and needing to see, drive, or verify its UI without a device or simulator. The mobai-cloud CLI previews the app in a phone sized viewport, returns the screen as a semantic tree, taps, types and scrolls by label, screenshots, hot reloads after edits, mocks location, permissions, camera, network and auth, and repairs native only dependencies with preview adapters. Covers Flutter, React Native and SwiftUI. Needs a free MobAI account (MOBAI_API_KEY or `mobai-cloud login`). Triggers on "preview", "run the app", "show me the screen", "tap", "type into", "screenshot", "mock", "scenario", "test the flow", "build the app", "mobai-cloud", "AUTH_REQUIRED".
---

# Previewing mobile apps

`mobai-cloud` gives this sandbox a phone shaped screen. It runs the app's real
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
mobai-cloud setup --framework flutter --json   # flutter | react-native (rn) | swiftui (ios)
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
handed its permission to run by `mobai-cloud`, which gets it from the MobAI
service, so a machine with no credential previews nothing. `AUTH_REQUIRED` is
what that looks like.

Two ways to hold one, and either is enough:

```bash
export MOBAI_API_KEY=mobai_...        # a key from the app; best for CI
```

or sign in, which is two ordinary commands and no prompt:

```bash
mobai-cloud login                                            # who am I, if anyone
mobai-cloud login --email you@example.com                    # sends a 6 digit code
mobai-cloud login --email you@example.com --code 123456      # verifies it
```

The code arrives by email, so ask the person you are working with for it and
run the second command. Nothing here needs a terminal or a browser. A stored
login is refreshed automatically afterwards; you do not sign in again per
preview.

The engine is installed like anything else in the list. It lands in
`~/.mobai/engines/<name>` and every later run finds it with no configuration:

```bash
mobai-cloud engines install rn --json                   # download and set up
mobai-cloud engines install rn --from <dir|.tar.gz>     # from a local copy
mobai-cloud engines list --json                         # what is installed
```

A missing engine also shows up later as `PREVIEW_ENGINE_MISSING` on any preview,
with the install command in its `suggestion`. A `bootstrap` of `stale` in the
listing means dependencies changed; run the install again.

## The loop

```bash
mobai-cloud preview run --detach --json                 # once
mobai-cloud preview inspect --json                      # what is on screen
mobai-cloud preview tap --label Continue --json
mobai-cloud preview type --label Email --text a@b.com --json
mobai-cloud preview scroll --direction down --amount 400 --json
# ...edit source...
mobai-cloud preview reload --json                       # pick the edit up
mobai-cloud preview inspect --json                      # confirm the change
mobai-cloud preview screenshot --out /tmp/shot.png --json
mobai-cloud preview stop --json                         # when done
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
| `AUTH_REQUIRED` | no MobAI account on this machine, or the stored login was rejected | set `MOBAI_API_KEY`, or `mobai-cloud login` (see [The account](#the-account)) |
| `ENGINE_NOT_PERMITTED` | the engine was started without its permission, which normally means it was run directly | start previews with `mobai-cloud preview`, never by calling the engine binary |
| `PREVIEW_UNSUPPORTED_MODULE` | a dependency cannot run in the preview | write an adapter; see [writing-preview-adapters.md](./writing-preview-adapters.md) |
| `PREVIEW_COMPILE_FAILED` | the source does not compile | `details.errors` carries the compiler output |
| `PREVIEW_MOCK_UNSUPPORTED` | capability not held by this engine | `details` lists what it does hold |

## Mocking the world

The app's environment, location, permissions, what the camera returns, what
the network answers, who is signed in, is data, not devices. Set it at start
with a scenario file, or change one capability live with no reload:

```bash
mobai-cloud preview run --detach --scenario scenarios/checkout.yaml --json
mobai-cloud mock location '{"lat":52.52,"lng":13.405,"label":"Berlin"}' --json
mobai-cloud mock permissions '{"camera":"denied"}' --json
mobai-cloud mock appearance dark --json
mobai-cloud preview mock-state --json                   # the world as it stands
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
  host app and takes minutes; later runs are fast.
- **React Native**: edits apply on their own through Fast Refresh; `reload` is
  a full page reload and loses component state, so it is rarely wanted.
  expo-router file based routing is supported.
- **SwiftUI**: `reload` recompiles and restarts behind the same port; the
  response carries `stateReset: true`, so re-drive to the screen under work
  after a reload. A failed edit answers `PREVIEW_BUILD_FAILED` and the old
  build keeps running. One hard limit: at most 32 dynamically generated rows
  per stack (a `ForEach` in a `List`, `ScrollView` or `Form`); more aborts
  with an `ENGINE_ERROR` naming this rule. Preview 20 rows; they show the same
  design decisions as 500.

## What the preview cannot answer

Native rendering fidelity, real gestures and keyboards, camera hardware,
performance, and how the App Store build behaves. When the question changes to
one of those, say so and move to a simulator or device instead of trusting the
preview past its limits. For layout, state, flow, copy, and error states, the
preview is measured against real devices and is the fast path.
