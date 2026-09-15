# Debrowse

[![Build](https://github.com/ystepanoff/debrowse/actions/workflows/build.yml/badge.svg)](https://github.com/ystepanoff/debrowse/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/ystepanoff/debrowse?display_name=tag&sort=semver)](https://github.com/ystepanoff/debrowse/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white)](#install)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](Package.swift)
[![Licence: MIT](https://img.shields.io/badge/licence-MIT-blue)](LICENSE)

A tiny macOS menu bar app for switching the default web browser. The menu bar shows the icon of
whatever browser is currently the default; click it, pick another browser, confirm the system
prompt, done. Handy when you want "Chrome for the next hour, Safari afterwards" without digging
through System Settings.

## Install

Requires macOS 13 Ventura or newer. The release build is universal (Apple silicon and Intel).

1. Download `Debrowse-vX.Y.Z.zip` from the [latest release](https://github.com/ystepanoff/debrowse/releases/latest)
   and unzip it.
2. Move `Debrowse.app` to `/Applications` and open it.
3. macOS will refuse the first launch because the app is not notarised (there is no paid Developer
   ID behind it). Either go to System Settings › Privacy & Security and click **Open Anyway**, or
   clear the quarantine flag yourself:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Debrowse.app
   ```

Every release ships with a `SHA256SUMS.txt` you can check the download against.

**Upgrading:** each build carries a fresh ad-hoc signature, so macOS may treat an upgraded copy as
a new app for Login Items. If "Launch at Login" shows unchecked after an upgrade, toggle it on again.

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
- **Launch at Login** registers the app as a login item. If macOS wants you to approve it first,
  the item shows a dash and clicking it opens System Settings › Login Items.
- **Open System Settings…** jumps to Desktop & Dock, where the default browser lives.
- The list refreshes every time you open the menu, and the icon polls every 5 seconds so changes
  made elsewhere (System Settings, a browser's own "make default" prompt) show up too.

Double-clicking the app in Finder while it is already running pops the menu open. There is no Dock
icon and no window; quit it from its menu.

## How it works

Debrowse asks macOS which installed apps can open both `http` and `https` links and lists those.
It is close to what System Settings shows, though some non-browser apps register for web links and
will appear too. Switching goes through the same system API that System Settings uses, which is
why macOS always asks you to confirm. Afterwards the app re-reads the actual handlers rather than
trusting the API's answer, so what the menu shows is what your Mac will really do.

## Build from source

You need the Apple Command Line Tools (`xcode-select --install`). No Xcode, no dependencies.

```sh
make            # builds ./build/Debrowse.app
make install    # builds, copies to /Applications, launches
make uninstall  # quits and removes /Applications/Debrowse.app
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for build options, project layout, and the release process.

## Licence

[MIT](LICENSE).
