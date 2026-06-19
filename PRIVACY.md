# Privacy Policy

RightHere is a local macOS Finder extension. Its core behavior runs on your Mac and does not require an account or a custom backend service.

## What RightHere Accesses

- FinderSync is used to add a "New File" menu to Finder context menus.
- Template files are read from RightHere's local template directory so new files can inherit your chosen template content.
- Local settings are stored in macOS UserDefaults.
- The app and extension share template metadata through the configured App Group container.

RightHere does not upload your templates, files, folder names, or Finder selections.

## Network Access

RightHere only contacts GitHub when you choose **Help & Feedback -> Check for Updates...** from the menu bar app.

That request reads GitHub Releases metadata and is used only to tell you whether a newer version is available. RightHere does not automatically download or install updates.

RightHere does not run analytics and does not send diagnostic information automatically.

## Feedback

The feedback menu opens a GitHub Issue page in your browser with diagnostic information prefilled. You can review and edit the text before submitting it.

The diagnostic text includes app version, macOS version, CPU architecture, template counts, enabled file extensions, extension response timing, and the local template directory path. It does not include template file contents or user file contents.
