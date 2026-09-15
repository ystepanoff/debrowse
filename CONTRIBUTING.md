# Contributing to Debrowse

Thanks for taking an interest. This file covers everything a contributor or maintainer needs that
an ordinary user does not: how the build works, where things live, how to debug, and how to cut a
release. Issues and pull requests are welcome.

## Prerequisites

- macOS 13 or newer.
- Apple Command Line Tools (`xcode-select --install`). Full Xcode is not required.

The build does not use SwiftPM or `xcodebuild`. `Package.swift` exists only so the sources open
cleanly in Xcode or a SwiftPM-aware editor; do not expect `swift build` to be the supported path.

## Building

```sh
make            # release build into ./build/Debrowse.app
make run        # build and launch from ./build
make list       # build, then print detected browsers and the current default
make install    # build, copy to /Applications (override with INSTALL_DIR=...), launch
make uninstall  # quit and remove the installed copy
make clean      # remove ./build
```

`Scripts/build-app.sh` does the work and honours two environment variables:

| Variable | Default            | Effect                                                      |
|----------|--------------------|-------------------------------------------------------------|
| `CONFIG` | `release`          | `release` (`-O -whole-module-optimization`) or `debug` (`-Onone -g`) |
| `ARCHS`  | host architecture  | Space-separated list; more than one produces a universal binary via `lipo` |

The script compiles all Swift sources with `swiftc` in Swift 5 language mode against a macOS 13
deployment target, assembles the bundle from `Resources/Info.plist`, renders the app icon with
`Scripts/make-icon.swift` (an `.iconset` turned into `.icns` by `iconutil`), and ad-hoc signs the
result. Ad-hoc signing means each build has a new code signature; that is fine for local use and
is what the released zips ship with too.

## Project layout

```
Sources/Debrowse/
  main.swift            app bootstrap (accessory activation policy) and the --list flag
  AppDelegate.swift     status item, menu construction, actions, deferred work while the menu is open
  BrowserManager.swift  discover browsers, read/set default via Launch Services
  Browser.swift         model + icon loading
  LoginItem.swift       SMAppService wrapper, including the requires-approval state
  Preferences.swift     UserDefaults-backed settings
Resources/Info.plist    bundle metadata (LSUIElement = true)
Scripts/build-app.sh    swiftc build + bundle assembly + signing
Scripts/make-icon.swift renders AppIcon.iconset -> .icns
.github/workflows/      CI: universal build on every push, GitHub release on v* tags
Makefile                thin wrapper over the build script
```

## How it works

- Browsers are the apps Launch Services reports for both `http://` and `https://` probe URLs
  (`NSWorkspace.urlsForApplications(toOpen:)`), deduplicated by bundle identifier and sorted by
  name. Whatever currently handles either scheme is always included, even if it only claims one.
- The current default is `NSWorkspace.urlForApplication(toOpen:)` for an `http` URL; the `https`
  handler is read separately so a split state can be shown and repaired.
- Switching calls `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for `http`, which
  triggers the system confirmation. macOS normally updates `https` as part of the same change; if
  it did not, the app sets `https` explicitly (possibly prompting again). The outcome is judged by
  re-reading both handlers, never by trusting the API's error value alone.
- The menu is rebuilt in `menuNeedsUpdate`. Anything that must not happen while the menu is
  tracking (rebuilding items, showing an alert) is queued until `menuDidClose`.
- Launch at Login uses `SMAppService.mainApp`; the `requiresApproval` status is surfaced as a mixed
  state that opens the Login Items pane when clicked.

## Debugging

- `build/Debrowse.app/Contents/MacOS/Debrowse --list` prints the detected browsers and the current
  default without starting the UI.
- `log show --predicate 'process == "Debrowse"' --last 5m` shows anything the app logged.
- A `debug` build (`CONFIG=debug make`) keeps symbols for `lldb`.

## Conventions

- Swift 5 language mode, AppKit only, no third-party dependencies.
- British spelling in all prose, UI strings, and comments (dialogue, colour, licence as a noun).
  API identifiers and compiler flags are left exactly as Apple spells them.
- Keep the menu bar app free of windows; anything that needs a UI beyond the menu is out of scope.

## Releasing

1. Bump `CFBundleShortVersionString` (and `CFBundleVersion` if you like) in `Resources/Info.plist`
   and commit.
2. Tag and push:

   ```sh
   git tag -a v1.1.0 -m "Debrowse 1.1.0"
   git push origin main --follow-tags
   ```

The workflow in `.github/workflows/build.yml` builds a universal binary, runs a smoke test
(`lipo`, `plutil`, `codesign --verify`, `--list`), and on a `v*` tag publishes a GitHub release
with the zipped app, a `SHA256SUMS.txt`, install notes, and a generated changelog.

If a tag push does not start a run (GitHub occasionally skips tags pushed together with brand-new
workflow files), trigger it by hand:

```sh
gh workflow run build.yml --ref v1.1.0
```

## Reporting issues

Please include your macOS version, the output of `--list`, and which browser you were switching
from and to. If the system prompt behaved unexpectedly, say whether you accepted or declined it.
