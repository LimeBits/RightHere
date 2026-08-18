# RightHere Release Checklist

Use this checklist before publishing a GitHub release.

## Version

- Update `MARKETING_VERSION` in `project.yml`.
- Update `MARKETING_VERSION` in `RightHere.xcodeproj/project.pbxproj` if the project file is committed directly.
- Add release notes to `CHANGELOG.md`.
- Update `RELEASE_NOTES.md` with **only the current version's** notes. This entire file is embedded in Sparkle's update window; retain history exclusively in `CHANGELOG.md`.
- Run `Scripts/release-preflight.sh --tag vX.Y.Z --dmg <exact-DMG> --notes RELEASE_NOTES.md`; do not publish if it fails.

## Build

- Run `bash -n deploy.sh Scripts/package-app.sh Scripts/package-dmg.sh Scripts/package-developer-id.sh Scripts/notarize.sh Scripts/generate-appcast.sh Scripts/release-preflight.sh Scripts/install.sh Scripts/doctor.sh Scripts/check-installed-version.sh monitor.sh`.
- Run a native Debug build:
  `DEVELOPMENT_TEAM=<TEAMID> ./deploy.sh --build --force`
- Run a Universal Debug build:
  `DEVELOPMENT_TEAM=<TEAMID> ./deploy.sh --build --universal --force`
- Confirm the app launches from the menu bar.
- Before any FinderSync smoke test, verify both `/Applications/RightHere.app` and its embedded `RightHereExtension.appex` use the expected `Developer ID Application` certificate and have a `TeamIdentifier`.
- Never use an ad-hoc, unsigned, or Apple Development-signed DMG to validate FinderSync after copying it to `/Applications`. Those packages can appear enabled in `pluginkit` while Finder refuses to load the extension.
- `pluginkit` is a registration check only; it is not proof that the Finder context menu is working.

## Smoke Test

- Install the exact DMG intended for testing into `/Applications`, then launch it once.
- Open RightHere settings.
- In Finder, actually right-click both a folder background and a file, and confirm RightHere menu items render and execute. Do not replace this step with a `pluginkit` check.
- Confirm Finder response status changes after opening a Finder context menu.
- Create a `.txt` file from Finder.
- Create a `.md` file from Finder.
- Create a `.docx`, `.xlsx`, or `.pptx` file from Finder.
- Confirm duplicate names are numbered instead of overwritten.
- Add a custom `template.rtf`, refresh templates, and create a new RTF file.
- Open **Help & Feedback -> Copy Diagnostic Info** and confirm the text is copied.
- Open **Help & Feedback -> Feedback...** and confirm GitHub Issues opens with prefilled text.
- Open **Help & Feedback -> Check for Updates...** and confirm the result is understandable.
- Confirm `PRIVACY.md` still matches the actual update and feedback behavior.

## Publish

- Commit source and documentation changes.
- Push `main`.
- Create and push an annotated tag matching the app version.
- GitHub Actions will create the GitHub Release from the tag.
- GitHub Actions will upload an unsigned CI DMG and `.sha256` checksum as release assets.
- Treat GitHub Actions assets as CI verification until Developer ID secrets/profiles are configured.
- For a cross-machine installable release, run `./Scripts/package-developer-id.sh`.
- Download the notarized Developer ID DMG and launch it once on a clean machine or test account.
- Validate the exact uploaded asset: its SHA-256 checksum, Gatekeeper acceptance, FinderSync signing, and the actual Finder right-click menu.

## Mandatory Release Gates

Developer ID signing, notarization, stapling validation, Gatekeeper verification, exact DMG selection, version matching, and release-note validation are mandatory for every public release. A CI or unsigned package must never be uploaded to the public Sparkle feed.
