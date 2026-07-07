# Numbra CI

Numbra's UI is tested with [mobai-ci](https://github.com/MobAI-App/mobai-ci),
which runs the `.mob` flows in `flows/` against a device and emits JUnit plus a
screenshot + UI tree for every failed step.

## Flows (`flows/`)

| Flow | What it checks |
| --- | --- |
| `01-launch.mob` | App installs, launches, and renders (onboarding CTA present). |
| `02-onboarding.mob` | Tapping through the onboarding slides reaches the photo picker. |
| `03-sample-canvas.mob` | Starting a sample painting generates and shows the paintable canvas. |

Flows assume a **clean install** (onboarding shows). On a reused device with
Numbra already onboarded they will land on the gallery instead — reinstall
clean, or adjust the anchors.

## Workflows (`.github/workflows/`)

| Workflow | Trigger | Where it runs |
| --- | --- | --- |
| `validate-flows.yml` | push / PR | Linux — parses flows, no device/build (fast gate). |
| `ios-sim.yml` | push / PR / manual | macOS — builds, boots a simulator, runs flows sharded across 2 runners. |
| `byod-tailscale.yml` | manual | Builds on macOS, drives a device on **your** host over a Tailscale tunnel. |
| `byod-public-ip.yml` | manual | Same, but reaches your host directly at a public IP (token required). |

The BYOD workflows are `workflow_dispatch` (manual) because they need your MobAI
desktop host awake with a device attached.

## Required secrets (Settings → Secrets → Actions)

Only needed for the BYOD workflows (the sim + validate jobs need none):

| Secret | Used by | Notes |
| --- | --- | --- |
| `MOBAI_API_KEY` | both BYOD | MobAI account key (`mobai_…`) from the app's API Keys dialog. BYOD is Pro-only. |
| `MOBAI_ADDR` | both BYOD | Host URL, e.g. `http://my-mac:8686` (Tailscale MagicDNS) or `http://<public-ip>:8686`. |
| `MOBAI_TOKEN` | both BYOD | Host API token. Optional for Tailscale, **required** for public IP. |
| `TS_OAUTH_CLIENT_ID` / `TS_OAUTH_SECRET` | Tailscale only | Tailscale OAuth client tagged `tag:ci`. |

## Notes / caveats

- Numbra targets **iOS 26.0**; the macOS runner must have the iOS 26 simulator
  (Xcode 26). Pin Xcode or lower the deployment target for CI if the default
  image lacks it.
- A **simulator** host takes the `.app` directly. A real iOS **device** host
  needs a signed `.ipa`.
- Sharding (`--shard i/N`) parallelizes across runners and is most useful on the
  sim matrix; a single BYOD device serializes regardless.
