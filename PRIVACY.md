<div align="center">

# Privacy Policy

English | [简体中文](PRIVACY.zh-CN.md)

</div>

RightHere is a local macOS Finder extension. Its core behavior runs on your Mac and does not require an account or a custom backend service.

## What RightHere Accesses

- FinderSync is used to add RightHere's items to Finder context menus.
- Template files are read from RightHere's local template directory so new files can inherit your chosen template content.
- Local settings are stored in macOS UserDefaults.
- The app and extension share template metadata through the configured App Group container.
- The extension keeps a rolling local buffer of up to 100 diagnostic events. These events may include local target paths, menu context, and file-creation results, but never file contents.

RightHere does not upload your templates, files, folder names, or Finder selections.

## Network Access

RightHere only contacts GitHub when you choose **Help & Feedback -> Check for Updates...** from the menu bar app.

That request reads GitHub Releases metadata and is used only to tell you whether a newer version is available.

RightHere also uses Sparkle 2 for in-app updates. Automatic checks can be turned off in the **Updates** tab of settings. Updates are only downloaded and installed after you confirm them.

RightHere does not run analytics and does not send diagnostic information automatically. Diagnostic events are synchronized locally between the extension and the menu bar app.

## Feedback

The feedback menu opens a GitHub Issue page in your browser with diagnostic information prefilled. You can review and edit the text before submitting it.

The diagnostic text includes app version, macOS version, CPU architecture, interface language, template counts, enabled file extensions, extension response timing, recent extension events, and relevant local paths. It does not include template file contents or user file contents.
