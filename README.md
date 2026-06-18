# HippoGUI

SwiftUI macOS app for browsing Hippo knowledge, events, sessions, and health status.

## Open in Xcode

HippoGUI now uses a package-first architecture:

- `HippoGUIKit` is the shared Swift package library containing the app UI, view models, services, and models
- `HippoGUI.xcodeproj` is a thin native macOS app host that depends on the local package
- `HippoGUIPackageApp` is a thin package executable host for `swift run` and script-based bundle builds

- Open `hippo-gui/HippoGUI.xcodeproj` for the standard macOS app target experience
- Open `hippo-gui/Package.swift` if you specifically want the Swift Package view

All paths below are relative to the repo root unless noted. Open the native app project from the terminal with:

```bash
cd hippo-gui
xed HippoGUI.xcodeproj
```

Open the package view with:

```bash
cd hippo-gui
xed Package.swift
```

## Run tests

```bash
cd hippo-gui
swift test
```

The package includes a `HippoGUITests` target built with Swift Testing.

For rapid iteration, prefer editing library code under `Sources/HippoGUI/` and validating with `swift test`. The native Xcode project only owns a tiny host file plus app metadata/resources.

## mise tasks

From the repo root, HippoGUI is also covered by `mise` tasks:

```bash
mise run gui:build
mise run gui:test
mise run gui:lint
mise run gui:format
mise run gui:open
```

Prerequisites:

- `swiftlint` — `brew install swiftlint`
- `swift-format` — `brew install swift-format`

## Release versioning

HippoGUI is versioned independently of the broader Hippo project, following [SemVer](https://semver.org). The `hippo-gui/VERSION` file is the single source of truth; releases are tagged `vX.Y.Z`.

- `HippoGUI` app bundle versions are stamped by `scripts/stamp-app-version.sh`
- `CFBundleShortVersionString` is resolved with the following precedence:
  1. `HIPPO_MARKETING_VERSION` environment variable, if set (for CI overrides)
  2. `hippo-gui/VERSION` file
- `CFBundleVersion` comes from `HIPPO_BUILD_NUMBER`, then `BUILD_NUMBER`, then the commit count of this repo (`git rev-list --count HEAD`)
- The same stamping flow is used by both `HippoGUI.xcodeproj` and `./scripts/build-native-app.sh`
- `./scripts/release-gui.sh` builds the native `.app`, creates a versioned `.zip`, writes sibling SHA-256 and Markdown release-notes files, and can emit CI-friendly JSON

To cut a release, bump `hippo-gui/VERSION`, commit, and tag:

```bash
$EDITOR hippo-gui/VERSION   # e.g. 1.0.0 -> 1.1.0
git commit -am "chore(release): bump to vX.Y.Z"
git tag vX.Y.Z
```

To inspect the stamped version in the script-built app:

```bash
cd hippo-gui
./scripts/build-native-app.sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/debug/HippoGUI.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' dist/debug/HippoGUI.app/Contents/Info.plist
```

To build a shareable release artifact bundle:

```bash
cd hippo-gui
./scripts/release-gui.sh
HIPPO_BUILD_NUMBER=501 ./scripts/release-gui.sh release
```

To print release-notes Markdown instead of the human summary:

```bash
cd hippo-gui
./scripts/release-gui.sh --markdown
```

To emit CI-friendly JSON metadata:

```bash
cd hippo-gui
./scripts/release-gui.sh --json
```

The release helper writes both:

- `dist/release/HippoGUI.app`
- `dist/release/HippoGUI-<version>-<build>.zip`
- `dist/release/HippoGUI-<version>-<build>.zip.sha256`
- `dist/release/HippoGUI-<version>-<build>.release-notes.md`

To verify the generated archive checksum later:

```bash
cd hippo-gui/dist/release
shasum -a 256 -c HippoGUI-<version>-<build>.zip.sha256
```

## Troubleshooting

### SwiftLint plugin crash: `Plug-in ended with uncaught signal: 5`

If a build fails with `Plug-in ended with uncaught signal: 5` and the full log shows:

```
SourceKittenFramework/library_wrapper.swift:58: Fatal error:
Loading sourcekitdInProc.framework/Versions/A/sourcekitdInProc failed
```

the SwiftLint build-tool plugin (via SourceKitten) is loading a `sourcekitd` that does not match the toolchain building the project. This happens when the active command-line developer directory points at `CommandLineTools` instead of the Xcode you're building with. Point `xcode-select` at that Xcode:

```bash
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

Adjust the path if you build with a different Xcode (e.g. `/Applications/Xcode.app/Contents/Developer`). Verify with `xcode-select -p`.

Rollback (restore the previous setting) with:

```bash
sudo xcode-select -s /Library/Developer/CommandLineTools
```

## About and Settings

- Open `HippoGUI > About HippoGUI` for a dedicated About window; repeating the command reuses and focuses the same window
- Open `HippoGUI > Settings…` to view the same build information in Settings
- Native `.app` launches show the stamped version/build metadata; non-bundled development runs fall back to development metadata
- The native Xcode target stamps app versions during build from the same shared versioning flow used by the release scripts

## Previews and mocks

SwiftUI previews are defined in the main view files and use `PreviewBrainClient` so they render without a live Hippo backend. Tests use a separate `MockBrainClient` under `Tests/` with recording/assertion helpers.

Useful files:

- `Sources/HippoGUI/Services/PreviewBrainClient.swift` — preview-only stub inside `HippoGUIKit`
- `Sources/HippoGUI/Services/BrainClientEnvironment.swift`
- `Sources/HippoGUIPackageApp/HippoGUIPackageApp.swift`
- `XcodeApp/HippoGUIXcodeApp.swift`
- `Tests/HippoGUITests/MockBrainClient.swift` — test double with recorded calls
- `Tests/HippoGUITests/ViewModelTests.swift`
- `Tests/HippoGUITests/DecodingTests.swift`

## App structure

- `Sources/HippoGUI/App/` — shared app shell types used by both hosts
- `Sources/HippoGUI/Models/` — Codable/Sendable response models
- `Sources/HippoGUI/Services/` — HTTP client, environment injection, config, mocks
- `Sources/HippoGUI/ViewModels/` — `@Observable @MainActor` view models
- `Sources/HippoGUI/Views/` — SwiftUI screens and reusable UI components
- `Sources/HippoGUIPackageApp/` — package executable host
- `XcodeApp/` — native Xcode app host
- `HippoGUI.xcodeproj/` — native macOS project that links the local `HippoGUIKit` package
