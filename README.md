# uFast

uFast is a calm, private iPhone companion for fasting, food, hydration and
progress. Manual features work offline and app-owned health information stays
on the device.

OW-000 establishes the SwiftUI project shell, four primary destinations,
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

To build, install and launch the latest code on one connected, unlocked iPhone:

```sh
make deploy-iphone
```

The script auto-detects a single connected iPhone and preserves its existing
app data. When more than one iPhone is connected, select one with
`DEVICE_ID=<CoreDevice identifier> make deploy-iphone`.

The default test destination is `iPhone 17 Pro`. Override it when needed:

```sh
make test SIMULATOR='platform=iOS Simulator,name=iPhone 17'
```

Open `uFast.xcodeproj` after `make bootstrap`. For a physical iPhone, select
your Apple Developer team and replace the example bundle identifier in
`project.yml`; simulator builds do not require signing.

### Environment verified for OW-000

- Xcode 26.0 (build 17A324)
- iOS 26.0.1 Simulator (build 23A8464)
- XcodeGen 2.46.0
- SwiftLint 0.65.0
- SwiftFormat 0.62.1
- iPhone 17 Pro simulator

## Repository documents

- `PRODUCT.md` — promise, goal, user, principles and measures
- `MVP_SCOPE.md` — MVP boundary and build sequence
- `DOMAIN_RULES.md` — shared terms and numbered behavioural rules
- `BACKLOG.md` — ordered starter backlog
- `READY_STORIES.md` — implementation-ready user stories
- `DECISIONS.md` — accepted product and architecture choices
- `AGENTS.md` — repository map, commands and Definition of Done
