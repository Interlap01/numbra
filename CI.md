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

### Account and repository setup

Follow Builder's [app creation and repository connection guide](https://github.com/MobAI-App/ios-builder/blob/1e7e5a5763e2a76d8601732076b15b7f72e514f4/docs/provider-setup.md)
for dashboard links, API tokens, app IDs, repository authorization, and YAML
selection. This needs the provider-enabled CLI from
[ios-builder PR #12](https://github.com/MobAI-App/ios-builder/pull/12);
Homebrew 0.7.0 does not include provider commands.

Numbra's existing apps are:

| Provider | App | Configuration |
| --- | --- | --- |
| Codemagic | [Numbra](https://codemagic.io/app/6a9bf5d20851f071f4320885) | Personal Account, `codemagic.yaml`, environment group `builder` |
| Bitrise | [Numbra](https://app.bitrise.io/app/7812c85a-da58-4943-b507-cc58f640a05e) | Private build visibility, repository `bitrise.yml`, Xcode 26.2 |

Both connect to [Interlap01/numbra](https://github.com/Interlap01/numbra) and use
`ci/macos-providers` for workflow configuration. Bitrise's GitHub connection and
repository YAML mode are now enabled. Connecting GitHub is required separately
from creating the API token or registering the app.

To configure another local checkout with these existing apps:

```sh
builder auth codemagic
builder auth bitrise
builder auth status
```

Use the committed `builder.json`, which already contains both app IDs. To create
apps for a different repository, follow the guide and use those apps' IDs.
`builder init --provider ...` replaces generated YAML, so review customized files
before rerunning it.

The workflow branch supplies the YAML and runner; Builder uploads the current
application source as a snapshot. After merging the setup PR, update both
provider `branch` values in `builder.json` to `main`, plus Bitrise's default
branch, before deleting `ci/macos-providers`.

The workflows request Codemagic M2 and Bitrise `g2.mac.medium` with no automatic
push triggers. Check the actual machine and credit usage in the build details:
Bitrise's verified build reported `g2.mac.large` despite the medium request.

### Signing and simulator access

Follow the [signing and MobAI secret setup guide](https://github.com/MobAI-App/ios-builder/blob/1e7e5a5763e2a76d8601732076b15b7f72e514f4/docs/provider-secrets.md)
for certificate/profile preparation, base64 clipboard commands on macOS/Linux/
Windows, MobAI key creation, and verification.

For Numbra's existing apps:

1. Open [Numbra in Codemagic](https://codemagic.io/app/6a9bf5d20851f071f4320885),
   select **Environment variables**, and add the values below to the existing
   **`builder`** group. Mark each value **Secret** and save it.
2. Open [Numbra in Bitrise](https://app.bitrise.io/app/7812c85a-da58-4943-b507-cc58f640a05e),
   select **Workflows → Secrets → Add new**, and save the same names/values as
   project secrets. Leave **Replace variables in inputs** and **Expose for Pull
   Requests** off.

| Name | Value |
| --- | --- |
| `IOS_CERTIFICATE` | Base64 Apple Development P12, including its private key |
| `IOS_CERTIFICATE_PASSWORD` | Original P12 password; do not base64-encode |
| `IOS_PROVISIONING_PROFILE` | Base64 iOS App Development profile for `run.mobai.numbra`, the same certificate/team, and registered devices |
| `MOBAI_API_KEY` | Key created in MobAI's **Account → API Keys**; paste the original value |

For simulator sharing, only `MOBAI_API_KEY` is needed. Signed iPhone builds need
all three `IOS_*` secrets. The generated runner exports development-signed IPAs.

Numbra already enables signing for GitHub. Configure `IOS_CERTIFICATE`
(base64 P12), `IOS_CERTIFICATE_PASSWORD`, and `IOS_PROVISIONING_PROFILE`
(base64 provisioning profile for `run.mobai.numbra`) separately in Codemagic's
`builder` group and Bitrise's app secrets. GitHub secrets cannot be downloaded
and copied by Builder. Until signing is configured, test with:

```sh
builder ios build --provider codemagic --unsigned
builder ios build --provider bitrise --unsigned
```

Once the three signing secrets are saved, verify signing without `--unsigned`:

```sh
builder ios build --provider codemagic
builder ios build --provider bitrise
```

Install the IPA on a device included in the profile to check provisioning.

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


### Verified unsigned builds

Both providers built `run.mobai.numbra` and Builder downloaded validated IPAs:

- [Codemagic build](https://codemagic.io/app/6a9bf5d20851f071f4320885/build/6a9bfb2ea63f14a97ef98a58): completed in 2m19s including download.
- [Bitrise build](https://app.bitrise.io/build/ecf8c1df-66f9-4e2d-82d2-dda9c462b25b): completed in 26s including download, using repository YAML and Xcode 26.2.

Bitrise stores unsigned IPAs with an `.ipa.zip` name as generic artifacts because
its installable-IPA uploader requires a provisioning profile. Builder validates
the unchanged IPA bytes and restores the `.ipa` extension on download. These
checks cover unsigned builds; signed builds and simulator sharing still require
the secrets listed above.
