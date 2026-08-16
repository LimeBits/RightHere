<div align="center">

# RightHere

**Do more from the Finder right-click menu**

[![Download](https://img.shields.io/github/v/release/LimeBits/RightHere?label=download&color=blue)](https://github.com/LimeBits/RightHere/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B-black)](https://github.com/LimeBits/RightHere/releases/latest)
[![Universal](https://img.shields.io/badge/arch-Intel%20%7C%20Apple%20Silicon-lightgrey)](https://github.com/LimeBits/RightHere/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

English | [简体中文](README.zh-CN.md)

</div>

RightHere makes four things faster in Finder: creating files, opening a terminal or editor at the current folder, jumping to frequently used or hidden paths, and copying paths for use elsewhere.

Built for people who move constantly between Finder, a terminal, and config files.

## Highlights

### New File

Create common file types straight from the Finder context menu, instead of opening an app and using Save As.

- Text, Markdown, Word, Excel, PowerPoint, and more
- Custom templates: drop your own template file in and it appears in the menu
- Choose which types show up, so the menu stays short
- Duplicate names are numbered automatically, e.g. `New Text Document (2)`

### Open Here

Open a terminal or editor with the current folder as its working directory, with no path copying or manual `cd`.

- Terminal, plus iTerm, Warp, VS Code, and Cursor when installed
- Only apps actually present on this Mac appear in the menu
- Works on a folder, a folder's empty space, and the desktop background
- Stays out of the file context menu to avoid competing with **Open With**

### Go To

Add frequently used files, folders, or hidden paths to the Finder context menu and reach them in one click.

- Ideal for hidden config paths like `~/.zshrc`, `/etc/hosts`, or `~/.codex`
- Add files, add folders, or type a path by hand
- Enable, hide, rename, or delete each entry individually
- Opening is performed by the main app, which avoids the sandbox limits that apply to a FinderSync extension

### Dev Tools

Copy path information for the selected items.

- Full path, file name, name without extension, containing folder, and Markdown link
- Multiple selections produce one result per line
- The containing-folder action de-duplicates when several files share a parent

### Language

The interface follows your system language, or you can pin it.

- English and Simplified Chinese
- **Follow System** by default
- Applies to the settings window, the Finder context menu, and the names of newly created files

### Lightweight Settings

Everything is managed from one small window.

- Manage file templates
- Toggle each context-menu tool
- Control what appears in the Finder context menu
- Lives in the menu bar and stays out of your way

## Install

Download the latest DMG from [GitHub Releases](https://github.com/LimeBits/RightHere/releases).

Drag `RightHere.app` into Applications, then open it once. The app registers and enables its Finder extension. If the context menu does not appear right away, quit and reopen Finder, or restart Finder and try again.

Requirements:

- macOS 12.0 or later
- Intel and Apple Silicon Macs

## Usage

### Creating a file

Right-click a folder's empty space or the desktop background:

```text
New File -> Plain Text / Markdown / Word Document / ...
```

### Managing templates

Open RightHere settings and use the **Templates** tab to choose which types appear in the context menu.

The first time you open the templates folder, RightHere creates the defaults:

```text
template.txt
template.md
template.docx
template.xlsx
template.pptx
```

Edit those directly, or add your own `template.<extension>` files:

```text
template.rtf
template.csv
template.json
template.swift
```

Refresh the settings page and the new templates appear in the list. Tick one and it shows up in Finder.

### Opening a terminal or editor

Right-click a folder, a folder's empty space, or the desktop background:

```text
Open Here -> Terminal / Cursor / VS Code / ...
```

Only apps installed on this Mac are listed. Terminal is enabled by default; third-party apps are opt-in from the **Tools** tab.

### Go To

Open RightHere settings and add files, folders, or paths in the **Tools** tab. Then, from the Finder context menu:

```text
Go To -> your file or folder
```

Good candidates:

```text
~/.zshrc
/etc/hosts
~/.codex
~/Library/Application Support
```

### Copying paths

Right-click one or more items:

```text
Dev Tools -> Copy Full Path / Copy File Name / Copy Markdown Link / ...
```

With several items selected you get one line per item.

### Changing the language

Open RightHere settings and use the **Language** control at the top of the **Advanced** tab. Choose **Follow System**, **English**, or **简体中文**.

Switching also changes the names of files created afterwards: `New Text Document.txt` in English, `新建文本文档.txt` in Chinese. Names you have already customized in Go To are kept as-is.

## Updates and Feedback

Choose **Help & Feedback -> Check for Updates…** from the menu bar to check for a new version.

Choose **Help & Feedback -> Report an Issue…** to open a GitHub Issue with diagnostic information prefilled. **Copy Diagnostic Info** puts the same text on the clipboard so you can paste it yourself.

RightHere runs no analytics and never uploads template or file contents. See [PRIVACY.md](PRIVACY.md).

## Local Development

Clone the repository and open `RightHere.xcodeproj` in Xcode. For ongoing local debugging, change the Team, bundle IDs, and App Group of both the main app and the FinderSync extension to your own values.

Common commands:

```bash
# Debug build for this machine + install to /Applications + enable the extension
./deploy.sh --build --force

# Universal Binary debug build (arm64 + x86_64)
./deploy.sh --build --universal --force

# Inspect the local toolchain, install state, and FinderSync status
./Scripts/doctor.sh

# Tail the FinderSync extension log
./monitor.sh
```

No personal Team ID is committed to this repository. Because RightHere uses an App Group and a FinderSync extension, local installs need development signing. Pass your Team ID through the environment:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --force
DEVELOPMENT_TEAM=YOURTEAMID ./deploy.sh --build --universal --force
```

You can also pick your Team under Signing & Capabilities for both targets. That edits the local project file, so check before committing that your Team ID has not been included.

## FinderSync Test and Signing Rules (Mandatory)

RightHere's context menu is provided by a `com.apple.FinderSync` extension, which has stricter runtime signing requirements than an ordinary menu-bar app. **The following are mandatory rules:**

1. Before testing the Finder context menu, both the main app and its embedded `RightHereExtension.appex` must be signed with the expected **Developer ID Application** certificate and include a valid `TeamIdentifier`.
2. **Never** install an ad-hoc, unsigned, or Apple Development-signed DMG into `/Applications` to test FinderSync. `pluginkit` may show such an extension as registered even when Finder refuses to load it.
3. A `+` from `pluginkit -m` proves registration/enabled state only. It never replaces an actual right-click test on a file and a folder background in Finder.
4. Normal `Scripts/package-dmg.sh` builds validate the Developer ID signature of both bundles and must fail rather than create a FinderSync test DMG when validation fails.
5. `--skip-signing` is only for CI or compilation checks. It must not be used for FinderSync testing, installed over `/Applications/RightHere.app`, uploaded to GitHub Releases, or included in the Sparkle feed.
6. Public releases must be made with `./Scripts/package-developer-id.sh`, which also notarizes and staples the package.

A locally testable Universal DMG is built with:

```bash
RIGHTHERE_DMG_SKIP_FINDER_LAYOUT=1 ./Scripts/package-dmg.sh --universal
```

The script must report:

```text
✓ 已验证主 App 与 Finder Sync 扩展的 Developer ID 签名。
```

## Distribution

Builds for other people must be Universal DMGs signed with a Developer ID, notarized, and stapled. The DMG produced by GitHub Actions is only useful for verifying the CI and packaging flow — it is not suitable for validating FinderSync on a clean machine.

To build a distributable package:

```bash
RIGHTHERE_DEVELOPMENT_TEAM=YOURTEAMID \
./Scripts/package-developer-id.sh
```

Before the first run, sign in to a valid Apple Developer account in Xcode and store notarytool credentials:

```bash
xcrun notarytool store-credentials "righthere-notary" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password"
```

RightHere uses Sparkle 2 for in-app updates. Whenever you upload a DMG, generate `appcast.xml` with `Scripts/generate-appcast.sh` and upload it to the same GitHub Release.

## FAQ

### The Finder context menu did not appear

**For users:** make sure the app came from GitHub Releases, is in Applications, and has been opened once. Then restart Finder if necessary:

```bash
killall Finder
```

**For development/testing:** follow the mandatory FinderSync signing rules above first. Do not treat `pluginkit` output as proof of success: actually right-click a file and a folder background. If the installed DMG is ad-hoc or Apple Development-signed, remove it and rebuild a verified test package with `Scripts/package-dmg.sh --universal`.

### Why does this need a FinderSync extension?

On macOS, adding items to the Finder context menu requires a FinderSync extension. The main app owns settings, templates, and Go To requests; the extension is what renders the menu inside Finder.

### Why does the main app perform Go To, rather than the extension?

A FinderSync extension runs sandboxed, which makes opening the home folder, hidden paths, and some system paths unreliable. RightHere writes the request to the App Group and wakes the main app to perform it instead.

### Does switching languages lose my settings?

No. Enabled templates are stored by file extension and their display names are computed at runtime, so switching languages never changes which templates are ticked. Go To entries you renamed keep your name; only the four built-in defaults follow the language.

## Repository Layout

```text
RightHere/              Main app (SwiftUI settings UI)
RightHereExtension/     FinderSync extension
Scripts/                Packaging, install, and diagnostic scripts
deploy.sh               One-command local deploy
monitor.sh              Live log monitor
DEVLOG.md               Notes on problems hit during development (Chinese)
```
