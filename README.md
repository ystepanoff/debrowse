# Debrowse

[![Build](https://github.com/ystepanoff/debrowse/actions/workflows/build.yml/badge.svg)](https://github.com/ystepanoff/debrowse/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ystepanoff/debrowse?display_name=tag&sort=semver)](https://github.com/ystepanoff/debrowse/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](#requirements)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

A tiny macOS menu bar app for switching the default web browser. The menu bar shows the icon of
whatever browser is currently the default; click it, pick another browser, confirm the system
prompt, done. Handy when you want "Chrome for the next hour, Safari afterwards" without digging
through System Settings.

## Requirements

macOS 13 Ventura or newer on Apple silicon or Intel. To build from source you also need the Apple
Command Line Tools (`xcode-select --install`). No Xcode, no dependencies.

## Install from a release

1. Download `Debrowse-vX.Y.Z.zip` from the [latest release](https://github.com/ystepanoff/debrowse/releases/latest)
   and unzip it.
2. Move `Debrowse.app` to `/Applications` and open it.
3. macOS will refuse the first launch because the app is not notarised (there is no paid Developer
   ID behind it). Either go to System Settings › Privacy & Security and click **Open Anyway**, or
   clear the quarantine flag yourself:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Debrowse.app
   ```

   Every release zip ships with a `SHA256SUMS.txt` you can check it against.

## Build from source

```sh
make            # builds ./build/Debrowse.app
make run        # builds and launches it from ./build
make install    # builds, copies to /Applications, launches
make uninstall  # quits and removes /Applications/Debrowse.app
```

`make install` puts the app in `/Applications`; override with `INSTALL_DIR=~/Applications make install`.
For a universal binary run `ARCHS="arm64 x86_64" make`.

The bundle is ad-hoc signed, so every build has a new code signature. After reinstalling, macOS
may treat it as a different app for Login Items: if "Launch at Login" shows unchecked after an
upgrade, just toggle it on again.

The build is a plain `swiftc` invocation (see `Scripts/build-app.sh`), which then assembles the
bundle, renders the app icon with `Scripts/make-icon.swift`, and ad-hoc signs the result. The
`Package.swift` is only there so the sources open cleanly in Xcode or in a SwiftPM-based editor.

## Using it

- **Menu bar icon** shows the current default browser. Toggle "Show Browser Icon in Menu Bar"
  off to get a neutral globe instead.
- **Pick a browser** from the list. macOS shows its own confirmation dialogue ("Use Firefox" / "Keep
  Safari"); accept it and both `http` and `https` links switch to the new browser. This dialogue is
  a system requirement and cannot be suppressed by any app. Declining it simply leaves things as
  they were.
- If `http` and `https` ever point at different browsers (possible if a second prompt is declined,
  or via other tools), the header says so, the browsers involved show a dash instead of a check,
  and picking the one you want repairs it.
- **Launch at Login** registers the app as a login item (only available when running from the
  `.app` bundle, e.g. after `make install`). If macOS wants you to approve it first, the item shows
  a dash and clicking it opens System Settings › Login Items.
- **Open System Settings…** jumps to Desktop & Dock, where the default browser lives.
- The list refreshes every time you open the menu, and the icon polls every 5 seconds so changes
  made elsewhere (System Settings, a browser's own "make default" prompt) show up too.

Double-clicking the app in Finder while it is already running pops the menu open.

## How it works

- Browsers are the apps Launch Services reports as handlers for both `http://` and `https://`
  URLs (`NSWorkspace.urlsForApplications(toOpen:)`), deduplicated by bundle identifier, plus
  whatever currently handles either scheme. This is close to, but not necessarily identical to,
  the list System Settings shows; some non-browser apps register for web URLs and will appear.
- The current default is `NSWorkspace.urlForApplication(toOpen:)` for an `http` URL.
- Switching uses `NSWorkspace.setDefaultApplication(at:toOpenURLsWithScheme:)` for `http`. macOS
  normally updates `https` at the same time; if it did not, the app sets `https` explicitly, which
  can mean a second confirmation prompt. The outcome is judged by re-reading the handlers, not by
  trusting the API's return value.
- The app is an `LSUIElement` (no Dock icon, no windows). Quit it from its menu.

A debugging aid: `build/Debrowse.app/Contents/MacOS/Debrowse --list` prints the detected browsers
and the current default, then exits (also `make list`).

## Layout

```
Sources/Debrowse/
  main.swift            app bootstrap (accessory activation policy) and --list
  AppDelegate.swift     status item, menu construction, actions
  BrowserManager.swift  discover browsers, read/set default via Launch Services
  Browser.swift         model + icon loading
  LoginItem.swift       SMAppService wrapper
  Preferences.swift     UserDefaults-backed settings
Resources/Info.plist    bundle metadata (LSUIElement = true)
Scripts/build-app.sh    swiftc build + bundle assembly + signing
Scripts/make-icon.swift renders AppIcon.iconset -> .icns
.github/workflows/      CI: universal build on every push, GitHub release on v* tags
```

## Releasing

Bump `CFBundleShortVersionString` in `Resources/Info.plist`, commit, then tag and push:

```sh
git tag -a v1.1.0 -m "Debrowse 1.1.0"
git push origin main --follow-tags
```

The workflow builds a universal binary, runs the smoke test, and attaches the zip and its checksum
to a GitHub release with generated notes.

## Licence

[MIT](LICENSE).
