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
- The sim job boots the simulator in the background and lets `mobai-ci` wait for
  it (`--wait-device`), so the ~2-3 min cold boot overlaps the app download and
  mobai-ci install instead of blocking a step of its own.


## Builder macOS providers

GitHub Actions remains the default in `builder.json`; existing `builder ios build`
and `builder ios share` commands keep using GitHub. Numbra uses the root
`project.yml`, the `Numbra` scheme, and an iOS 26 SDK. The shared runner generates
its Xcode project with XcodeGen.

`codemagic.yaml`, `bitrise.yml`, and `.builder/ci/runner.sh` provide the
`ios-build` (IPA) and `ios-share` (MobAI simulator) workflows. These workflows
run when dispatched by Builder. They do not replace the GitHub UI test jobs.

### Complete account setup

This configuration requires the provider-enabled Builder CLI from
[ios-builder PR #12](https://github.com/MobAI-App/ios-builder/pull/12).
Homebrew version 0.7.0 does not include these commands. Until a release is
available, build the `feat/macos-ci-providers` branch of ios-builder and use that
binary for the commands below.

Register `https://github.com/Interlap01/numbra.git` with both providers, then:

```sh
builder auth codemagic
builder auth bitrise
builder auth status
builder init --provider codemagic --app-id YOUR_CODEMAGIC_APP_ID --branch main
builder init --provider bitrise --app-id YOUR_BITRISE_APP_SLUG --branch main
```

Codemagic is connected as app `6a9bf5d20851f071f4320885`, using the
`ci/macos-providers` branch for workflow configuration. Bitrise is connected as
app `7812c85a-da58-4943-b507-cc58f640a05e` in the existing workspace, with private
build visibility and repository YAML. Both providers use `ci/macos-providers`. Login prompts hide API tokens and save each account
independently; do not put tokens in repository files.

Commit the updated `builder.json` and merge these workflow files into `main`
before dispatching. To test before merging, configure `--branch ci/macos-providers`
and push the workflow files there. The configured branch supplies the workflow
and runner; Builder uploads the current application source as a snapshot.

- **Codemagic:** use a personal account and repository YAML. The workflow selects
  the M2 Mac. Create an accessible environment group named `builder`; add
  `BUILDER=1` for unsigned builds. Its Xcode selection is `latest`, which must
  include the iOS 26 SDK.
- **Bitrise:** the committed YAML selects Xcode 26.2; enable configuration
  from the repository's `bitrise.yml`, and disable onboarding-generated push
  triggers. The workflow selects `g2.mac.medium`; keep the app timeout at or
  below 90 minutes.

See the official [Codemagic app setup](https://docs.codemagic.io/getting-started/adding-apps/)
and [Bitrise app setup](https://docs.bitrise.io/en/bitrise-ci/getting-started/adding-a-new-project)
guides for connecting the repository.

### Signing and simulator access

Numbra already enables signing for GitHub. Configure `IOS_CERTIFICATE`
(base64 P12), `IOS_CERTIFICATE_PASSWORD`, and `IOS_PROVISIONING_PROFILE`
(base64 provisioning profile for `run.mobai.numbra`) separately in Codemagic's
`builder` group and Bitrise's app secrets. GitHub secrets cannot be downloaded
and copied by Builder. Until signing is configured, test with:

```sh
builder ios build --provider codemagic --unsigned
builder ios build --provider bitrise --unsigned
```

Unsigned IPAs do not install directly on an iPhone. Simulator sharing needs
`MOBAI_API_KEY` on each provider and a MobAI account supporting CI devices:

```sh
builder ios share --provider codemagic --duration 20m
builder ios share --provider bitrise --duration 20m
```

The CLI prints the run URL, cancellation command, and snapshot cleanup command.
New-provider sharing returns once submitted; check the run for readiness and
release or cancel sessions when finished. Provider selection is manual; free
allowances are account-specific and are not pooled by Builder.
