import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    private struct PendingMenuAction {
        let template: FileTemplate
        let targetDirectory: URL
        let allowsNonFinderFrontmost: Bool
        let createdAt: Date
    }

    private var enabledTemplates: [FileTemplate] = SharedDefaults.defaultFileTemplates
    private var templateRecordsByExtension: [String: TemplateRecord] = Dictionary(
        uniqueKeysWithValues: SharedDefaults.defaultFileTemplates.compactMap { template in
            SharedDefaults.getLocalTemplateRecord(for: template).map { (template.fileExtension, $0) }
        }
    )
    private var pendingMenuActions: [Int: PendingMenuAction] = [:]
    private var nextMenuActionTag = 1

    override init() {
        super.init()

        configureWatchedDirectories()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsChanged(_:)),
            name: Notification.Name("com.LimeBits.RightHere.SettingsChanged"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(diagnosticSnapshotRequested(_:)),
            name: SharedDefaults.extensionDiagnosticSnapshotRequestName,
            object: nil
        )

        recordDiagnostic("extension initialized pid=\(ProcessInfo.processInfo.processIdentifier)")
        SharedDefaults.publishExtensionDiagnosticSnapshot()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func settingsChanged(_ notification: Notification) {
        guard let enabledExtensions = notification.userInfo?["enabledExtensions"] as? [String] else {
            return
        }

        if let data = notification.userInfo?["templateRecords"] as? Data,
           let records = try? JSONDecoder().decode([TemplateRecord].self, from: data) {
            templateRecordsByExtension = Dictionary(
                uniqueKeysWithValues: records.map { ($0.template.fileExtension, $0) }
            )
        }

        let enabled = Set(enabledExtensions.map { $0.lowercased() })
        let availableTemplates = Array(templateRecordsByExtension.values.map { $0.template }).sorted()
        enabledTemplates = availableTemplates.filter { enabled.contains($0.fileExtension) }
    }

    @objc private func diagnosticSnapshotRequested(_ notification: Notification) {
        SharedDefaults.publishExtensionDiagnosticSnapshot()
    }

    private func configureWatchedDirectories() {
        guard let homeURL = realHomeDirectoryURL() else {
            FIFinderSyncController.default().directoryURLs = []
            NSLog("RightHereExtension: no real home directory found; watching no directories")
            return
        }

        FIFinderSyncController.default().directoryURLs = [homeURL]
        NSLog("RightHereExtension: watching Finder home directory tree: %@", homeURL.path)
    }

    private func realHomeDirectoryURL() -> URL? {
        guard let pw = getpwuid(getuid()) else { return nil }
        return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir), isDirectory: true)
    }

    private func updateHeartbeat() {
        SharedDefaults.markExtensionActive()
    }

    private func recordDiagnostic(_ message: String) {
        NSLog("RightHereExtension: %@", message)
        SharedDefaults.recordExtensionDiagnostic(message)
    }

    private var frontmostApplicationIdentifier: String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "<unknown>"
    }

    private func menuKindDescription(_ menuKind: FIMenuKind) -> String {
        switch menuKind {
        case .contextualMenuForItems:
            return "items"
        case .contextualMenuForContainer:
            return "container"
        case .contextualMenuForSidebar:
            return "sidebar"
        case .toolbarItemMenu:
            return "toolbar"
        @unknown default:
            return "unknown(\(menuKind.rawValue))"
        }
    }

    private func diagnosticPath(_ url: URL?) -> String {
        url?.standardizedFileURL.path ?? "<nil>"
    }

    private func diagnosticPaths(_ urls: [URL]?) -> String {
        guard let urls, !urls.isEmpty else { return "<none>" }
        return urls.map { $0.standardizedFileURL.path }.joined(separator: " | ")
    }

    private func isDesktopDirectory(_ directory: URL) -> Bool {
        guard let homeURL = realHomeDirectoryURL() else { return false }
        let desktopURL = homeURL.appendingPathComponent("Desktop", isDirectory: true)
        return directory.standardizedFileURL.path == desktopURL.standardizedFileURL.path
    }

    private func nextActionTag() -> Int {
        let tag = nextMenuActionTag
        nextMenuActionTag = nextMenuActionTag == Int.max ? 1 : nextMenuActionTag + 1
        return tag
    }

    private func removeExpiredMenuActions() {
        let expirationDate = Date().addingTimeInterval(-300)
        pendingMenuActions = pendingMenuActions.filter { $0.value.createdAt >= expirationDate }
    }

    // MARK: - Finder Sync Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        updateHeartbeat()

        let controller = FIFinderSyncController.default()
        let frontmostIdentifier = frontmostApplicationIdentifier
        let finderFrontmost = frontmostIdentifier == "com.apple.finder"
        let targetedURL = controller.targetedURL()
        let selectedURLs = controller.selectedItemURLs()
        let kindDescription = menuKindDescription(menuKind)

        recordDiagnostic(
            "menu request pid=\(ProcessInfo.processInfo.processIdentifier) "
                + "kind=\(kindDescription) frontmost=\(frontmostIdentifier) "
                + "finderFrontmost=\(finderFrontmost ? "yes" : "no") "
                + "targeted=\(diagnosticPath(targetedURL)) selected=\(diagnosticPaths(selectedURLs))"
        )

        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            recordDiagnostic("menu rejected kind=\(kindDescription) reason=unsupported-menu-kind")
            return nil
        }
        guard let targetDir = currentTargetDirectory(
            for: menuKind,
            targetedURL: targetedURL,
            selectedURLs: selectedURLs
        ) else {
            recordDiagnostic("menu rejected kind=\(kindDescription) reason=missing-target-directory")
            return nil
        }

        let isDesktopException = !finderFrontmost
            && menuKind == .contextualMenuForContainer
            && isDesktopDirectory(targetDir)
        guard finderFrontmost || isDesktopException else {
            recordDiagnostic(
                "menu rejected kind=\(kindDescription) reason=finder-not-frontmost "
                    + "target=\(diagnosticPath(targetDir))"
            )
            return nil
        }
        guard isAllowedMenuDirectory(targetDir) else {
            recordDiagnostic(
                "menu rejected kind=\(kindDescription) reason=disallowed-target-directory "
                    + "target=\(diagnosticPath(targetDir))"
            )
            return nil
        }

        let activeTemplates = enabledTemplates
        guard !activeTemplates.isEmpty else {
            recordDiagnostic("menu rejected kind=\(kindDescription) reason=no-enabled-templates")
            return nil
        }

        let mode = isDesktopException ? "desktop-exception" : "finder-frontmost"
        recordDiagnostic(
            "menu accepted kind=\(kindDescription) mode=\(mode) "
                + "target=\(diagnosticPath(targetDir)) templates=\(activeTemplates.count)"
        )
        removeExpiredMenuActions()

        let mainMenu = NSMenu(title: "")
        mainMenu.autoenablesItems = false

        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        newFileItem.isEnabled = true

        let submenu = NSMenu(title: "新建文件")
        submenu.autoenablesItems = false

        for template in activeTemplates {
            let item = NSMenuItem(title: template.displayName, action: #selector(createNewFile(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = true
            item.tag = nextActionTag()
            pendingMenuActions[item.tag] = PendingMenuAction(
                template: template,
                targetDirectory: targetDir,
                allowsNonFinderFrontmost: isDesktopException,
                createdAt: Date()
            )
            submenu.addItem(item)
        }

        newFileItem.submenu = submenu
        mainMenu.addItem(newFileItem)
        return mainMenu
    }

    @objc func createNewFile(_ sender: NSMenuItem) {
        let controller = FIFinderSyncController.default()
        let frontmostIdentifier = frontmostApplicationIdentifier
        let finderFrontmost = frontmostIdentifier == "com.apple.finder"
        let targetedURL = controller.targetedURL()
        let selectedURLs = controller.selectedItemURLs()

        recordDiagnostic(
            "create request pid=\(ProcessInfo.processInfo.processIdentifier) tag=\(sender.tag) "
                + "frontmost=\(frontmostIdentifier) finderFrontmost=\(finderFrontmost ? "yes" : "no") "
                + "targeted=\(diagnosticPath(targetedURL)) selected=\(diagnosticPaths(selectedURLs))"
        )

        guard let action = pendingMenuActions.removeValue(forKey: sender.tag) else {
            recordDiagnostic("create rejected reason=missing-menu-context tag=\(sender.tag)")
            return
        }
        let template = action.template
        let targetDir = action.targetDirectory

        guard finderFrontmost || action.allowsNonFinderFrontmost else {
            recordDiagnostic("create rejected reason=finder-not-frontmost")
            return
        }
        guard isAllowedMenuDirectory(targetDir) else {
            recordDiagnostic(
                "create rejected reason=disallowed-target-directory target=\(diagnosticPath(targetDir))"
            )
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: targetDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            recordDiagnostic(
                "create rejected reason=target-directory-unavailable target=\(diagnosticPath(targetDir))"
            )
            return
        }

        recordDiagnostic(
            "create accepted template=\(template.fileExtension) target=\(diagnosticPath(targetDir))"
        )

        guard let templateRecord = templateRecordsByExtension[template.fileExtension] else {
            recordDiagnostic("create failed reason=template-record-missing template=\(template.templateFileName)")
            return
        }

        let fileManager = FileManager.default

        // Find a non-colliding destination name
        var destinationURL = targetDir.appendingPathComponent("\(template.defaultFileName).\(template.fileExtension)")
        var count = 2
        while fileManager.fileExists(atPath: destinationURL.path) {
            destinationURL = targetDir.appendingPathComponent("\(template.defaultFileName) (\(count)).\(template.fileExtension)")
            count += 1
        }

        do {
            try templateRecord.data.write(to: destinationURL, options: .atomic)
            recordDiagnostic("create succeeded destination=\(diagnosticPath(destinationURL))")
        } catch {
            recordDiagnostic(
                "create failed destination=\(diagnosticPath(destinationURL)) error=\(error.localizedDescription)"
            )
        }
    }

    private func currentTargetDirectory(
        for menuKind: FIMenuKind,
        targetedURL: URL?,
        selectedURLs: [URL]?
    ) -> URL? {
        if menuKind == .contextualMenuForContainer {
            guard let targetedURL else { return nil }
            return directoryURL(for: targetedURL)
        }

        if let targetedURL {
            return directoryURL(for: targetedURL)
        }

        if let selected = selectedURLs?.first {
            return directoryURL(for: selected)
        }

        return nil
    }

    private func directoryURL(for url: URL) -> URL {
        if url.hasDirectoryPath {
            return url
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                return url
            }
        } catch {
            NSLog("RightHereExtension: failed to read URL resource values: %@", error.localizedDescription)
        }

        return url.deletingLastPathComponent()
    }

    private func isAllowedMenuDirectory(_ directory: URL) -> Bool {
        let path = directory.standardizedFileURL.path

        if path == "/" || path == "/Applications" || path.hasPrefix("/Applications/") {
            return false
        }

        guard let homeURL = realHomeDirectoryURL() else { return true }
        let homePath = homeURL.standardizedFileURL.path
        let sensitiveHomePaths = [
            "\(homePath)/Library",
            "\(homePath)/Library/Containers",
            "\(homePath)/Library/Group Containers"
        ]

        return !sensitiveHomePaths.contains { path == $0 || path.hasPrefix("\($0)/") }
    }
}
