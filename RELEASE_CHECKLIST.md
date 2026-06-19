# RightHere Release Checklist

Use this checklist before publishing a GitHub release.

## Version

- Update `MARKETING_VERSION` in `project.yml`.
- Update `MARKETING_VERSION` in `RightHere.xcodeproj/project.pbxproj` if the project file is committed directly.
- Add release notes to `CHANGELOG.md`.
- Update `RELEASE_NOTES.md` for the current release.

## Build

- Run `bash -n deploy.sh Scripts/package-app.sh Scripts/package-dmg.sh Scripts/install.sh Scripts/doctor.sh Scripts/check-installed-version.sh monitor.sh`.
- Run a native Debug build:
  `DEVELOPMENT_TEAM=<TEAMID> ./deploy.sh --build --force`
- Run a Universal Debug build:
  `DEVELOPMENT_TEAM=<TEAMID> ./deploy.sh --build --universal --force`
- Confirm the app launches from the menu bar.
- Confirm the FinderSync extension is enabled.

## Smoke Test

- Open RightHere settings.
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
- GitHub Actions will upload the generated Universal DMG and `.sha256` checksum as release assets.
- Download the uploaded asset and launch it once on a clean machine or test account.

## Future Signing

Before broad public distribution, add Developer ID signing and notarization so macOS Gatekeeper presents a trustworthy install experience.
