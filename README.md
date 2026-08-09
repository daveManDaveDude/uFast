# uFast

uFast is a calm, private iPhone companion for fasting, food, hydration and
history. Manual features work offline and app-created records stay on this
iPhone in a local SwiftData store.

OW-000 establishes the SwiftUI project shell, three primary destinations,
SwiftData persistence, deterministic fixtures, test targets and repository
guidance. Later stories supply user-facing behaviour.

## Requirements

- macOS with Xcode 26.0 or later in `/Applications/Xcode.app`
- iOS 26 Simulator runtime
- [Homebrew](https://brew.sh)
- XcodeGen 2.46 or later, SwiftLint and SwiftFormat (installed by bootstrap)

On a Mac that has never built an iPhone app, open Xcode once to allow it to
install required components. Optionally make this Xcode the system default:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

The repository commands set `DEVELOPER_DIR` themselves, so the system-wide
switch is convenient but not required.

If `xcrun simctl list runtimes` does not show iOS 26, install the matching
runtime (an approximately 8 GB first-time download):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -downloadPlatform iOS
```

## Setup and verification

```sh
make bootstrap
make build
make test
make lint
```

The 1.0 release baseline is iPhone-only, targets iOS 26.0, uses bundle ID
`com.davidmcgrath.uFast`, and is currently versioned from `project.yml` as
1.0.0 (build 6). Build 5 is the App Store review candidate; build 6 is the
current external TestFlight build.
It has no account, cloud sync, backup, restore, HealthKit, Live Activity,
notification or analytics dependency. Deleting the app may remove its local
data; uFast does not provide recovery.

To build, install and launch the latest code on one connected, unlocked iPhone:

```sh
make deploy-iphone
```

The script auto-detects a single connected iPhone and preserves its existing
app data. When more than one iPhone is connected, select one with
`DEVICE_ID=<CoreDevice identifier> make deploy-iphone`.

Deploy to both configured development iPhones with:

```sh
make deploy-iphones
```

Override the configured set when needed with
`DEVICE_IDS="<CoreDevice identifier> <CoreDevice identifier>" make deploy-iphones`.

To create and upload a TestFlight build, run:

```sh
make testflight
```

This runs unit tests and lint, increments `CURRENT_PROJECT_VERSION`, archives a
Release build, and uploads it to App Store Connect. Set
`TESTFLIGHT_SKIP_CHECKS=1` only when the same revision has already passed those
checks.

The default test destination is `iPhone 17 Pro`. Override it when needed:

```sh
make test SIMULATOR='platform=iOS Simulator,name=iPhone 17'
```

Open `uFast.xcodeproj` after `make bootstrap`. The project is configured for
the uFast Apple Developer identity; simulator builds do not require signing.

### Environment verified for OW-000

- Xcode 26.0 (build 17A324)
- iOS 26.0.1 Simulator (build 23A8464)
- XcodeGen 2.46.0
- SwiftLint 0.65.0
- SwiftFormat 0.62.1
- iPhone 17 Pro simulator

## Repository documents

- `PRODUCT.md` — promise, goal, user, principles and measures
- `ROADMAP.md` — current release position and phased post-MVP direction
- `MVP_SCOPE.md` — MVP boundary and build sequence
- `DOMAIN_RULES.md` — shared terms and numbered behavioural rules
- `BACKLOG.md` — ordered starter backlog
- `READY_STORIES.md` — implementation-ready user stories
- `SLICE_1_5_UX_STORIES.md` — visual contract and implementation-ready fasting
  experience stories
- `SLICE_2_TODAY_STORIES.md` — implementation-ready food, hydration and Today
  stories
- `SLICE_3_CATCH_UP_STORIES.md` — implementation-ready historical entry,
  reconstruction, provenance and invalidation stories
- `UX_STYLE_GUIDE.md` — quick-reference design tokens, components, artwork,
  accessibility rules and visual Definition of Done
- `DECISIONS.md` — accepted product and architecture choices
- `AGENTS.md` — repository map, commands and Definition of Done
- `PRIVACY.md` — public-facing local-data and safety policy
- `SUPPORT.md` — public-facing support and local-data limitations
