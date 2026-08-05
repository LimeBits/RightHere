import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    private struct PendingMenuAction {
        let template: FileTemplate
        let targetDirectory: URL
        let allowsNonFinderFrontmost: Bool
        let createdAt: Date
    }

    private struct PendingOpenHereAction {
        let app: OpenHereApp
        let directory: URL
        let allowsNonFinderFrontmost: Bool
        let createdAt: Date
    }

    private struct PendingShortcutAction {
        let location: ShortcutLocation
        let createdAt: Date
    }

    private struct PendingDevToolAction {
        let action: DevToolAction
        let targets: [URL]
        let allowsNonFinderFrontmost: Bool
        let createdAt: Date
    }

    private var enabledTemplates: [FileTemplate] = SharedDefaults.getEnabledFileTemplates()
    private var templateRecordsByExtension: [String: TemplateRecord] = Dictionary(
        uniqueKeysWithValues: SharedDefaults.getAvailableFileTemplates().compactMap { template in
            SharedDefaults.getTemplateRecord(for: template).map { (template.fileExtension, $0) }
        }
    )
    private var isFinderMenuDisabled = SharedDefaults.isFinderMenuDisabled()
    private var isOpenInTerminalEnabled = SharedDefaults.isOpenInTerminalEnabled()
    private var areShortcutLocationsEnabled = SharedDefaults.areShortcutLocationsEnabled()
    private var areDevToolsEnabled = SharedDefaults.areDevToolsEnabled()
    private var openHereAppSettings = SharedDefaults.getOpenHereAppSettings()
    private var shortcutLocations = SharedDefaults.getShortcutLocations()
    private var pendingMenuActions: [Int: PendingMenuAction] = [:]
    private var pendingOpenHereActions: [Int: PendingOpenHereAction] = [:]
    private var pendingShortcutActions: [Int: PendingShortcutAction] = [:]
    private var pendingDevToolActions: [Int: PendingDevToolAction] = [:]
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
        if let data = notification.userInfo?["templateRecords"] as? Data,
           let records = try? JSONDecoder().decode([TemplateRecord].self, from: data) {
            templateRecordsByExtension = Dictionary(
                uniqueKeysWithValues: records.map { ($0.template.fileExtension, $0) }
            )
        } else {
            templateRecordsByExtension = Dictionary(
                uniqueKeysWithValues: SharedDefaults.getAvailableFileTemplates().compactMap { template in
                    SharedDefaults.getTemplateRecord(for: template).map { (template.fileExtension, $0) }
                }
            )
        }

        if let enabledExtensions = notification.userInfo?["enabledExtensions"] as? [String] {
            let enabled = Set(enabledExtensions.map { $0.lowercased() })
            let availableTemplates = Array(templateRecordsByExtension.values.map { $0.template }).sorted()
            enabledTemplates = availableTemplates.filter { enabled.contains($0.fileExtension) }
        } else {
            enabledTemplates = SharedDefaults.getEnabledFileTemplates()
        }

        isFinderMenuDisabled = SharedDefaults.isFinderMenuDisabled()
        isOpenInTerminalEnabled = SharedDefaults.isOpenInTerminalEnabled()
        areShortcutLocationsEnabled = SharedDefaults.areShortcutLocationsEnabled()
        areDevToolsEnabled = SharedDefaults.areDevToolsEnabled()
        if let data = notification.userInfo?["shortcutLocations"] as? Data,
           let locations = try? JSONDecoder().decode([ShortcutLocation].self, from: data) {
            shortcutLocations = locations.map { $0.normalized() }.sorted()
        } else {
            shortcutLocations = SharedDefaults.getShortcutLocations()
        }

        if let data = notification.userInfo?["openHereApps"] as? Data,
           let settings = try? JSONDecoder().decode([OpenHereAppSetting].self, from: data) {
            openHereAppSettings = settings
        } else {
            openHereAppSettings = SharedDefaults.getOpenHereAppSettings()
        }

        // Seed the language straight from the payload when it is there, so this
        // process never reads the App Group container just to learn the language
        // (DEVLOG 坑 13). Falling back to invalidation still works, it just costs
        // one defaults read on the next menu build.
        if let raw = notification.userInfo?["preferredLanguage"] as? String,
           let language = RightHereLanguage(rawValue: raw) {
            RightHereLanguage.applyCachedLanguage(language)
        } else {
            RightHereLanguage.invalidateCache()
        }
    }

    @objc private func diagnosticSnapshotRequested(_ notification: Notification) {
        SharedDefaults.publishExtensionDiagnosticSnapshot()
    }

    private func reloadTemplatesFromSharedState() {
        templateRecordsByExtension = Dictionary(
            uniqueKeysWithValues: SharedDefaults.getAvailableFileTemplates().compactMap { template in
                SharedDefaults.getTemplateRecord(for: template).map { (template.fileExtension, $0) }
            }
        )
        enabledTemplates = SharedDefaults.getEnabledFileTemplates()
        isFinderMenuDisabled = SharedDefaults.isFinderMenuDisabled()
        isOpenInTerminalEnabled = SharedDefaults.isOpenInTerminalEnabled()
        areShortcutLocationsEnabled = SharedDefaults.areShortcutLocationsEnabled()
        areDevToolsEnabled = SharedDefaults.areDevToolsEnabled()
        openHereAppSettings = SharedDefaults.getOpenHereAppSettings()
        shortcutLocations = SharedDefaults.getShortcutLocations()
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
        pendingOpenHereActions = pendingOpenHereActions.filter { $0.value.createdAt >= expirationDate }
        pendingShortcutActions = pendingShortcutActions.filter { $0.value.createdAt >= expirationDate }
        pendingDevToolActions = pendingDevToolActions.filter { $0.value.createdAt >= expirationDate }
    }

    // MARK: - Finder Sync Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        updateHeartbeat()
        reloadTemplatesFromSharedState()

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

        guard !isFinderMenuDisabled else {
            recordDiagnostic("menu rejected kind=\(kindDescription) reason=finder-menu-disabled")
            return nil
        }

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
        let openHereDirectory = openHereTargetDirectory(
            for: menuKind,
            targetedURL: targetedURL,
            selectedURLs: selectedURLs
        )
        let activeShortcutLocations = areShortcutLocationsEnabled
            ? shortcutLocations.filter { $0.isEnabled && !$0.expandedPath.isEmpty }
            : []
        let activeOpenHereApps = isOpenInTerminalEnabled
            ? openHereAppSettings.filter { $0.isEnabled && $0.app.isInstalled }.map { $0.app }
            : []
        let devToolTargets = areDevToolsEnabled
            ? devToolTargets(
                for: menuKind,
                targetedURL: targetedURL,
                selectedURLs: selectedURLs
            )
            : []
        let activeDevToolActions = DevToolAction.allCases.filter { $0.isApplicable(to: devToolTargets) }

        let mode = isDesktopException ? "desktop-exception" : "finder-frontmost"
        recordDiagnostic(
            "menu accepted kind=\(kindDescription) mode=\(mode) "
                + "target=\(diagnosticPath(targetDir)) templates=\(activeTemplates.count) "
                + "openHere=\(openHereDirectory == nil ? "no-dir" : "\(activeOpenHereApps.count) apps") "
                + "shortcuts=\(activeShortcutLocations.count) devTools=\(activeDevToolActions.count)"
        )
        removeExpiredMenuActions()

        let mainMenu = NSMenu(title: "")
        mainMenu.autoenablesItems = false

        if !activeTemplates.isEmpty {
            let newFileItem = NSMenuItem(title: L("New File"), action: nil, keyEquivalent: "")
            newFileItem.isEnabled = true

            let submenu = NSMenu(title: L("New File"))
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
        }

        if let openHereDirectory, !activeOpenHereApps.isEmpty {
            let openHereItem = NSMenuItem(title: L("Open Here"), action: nil, keyEquivalent: "")
            openHereItem.isEnabled = true

            let submenu = NSMenu(title: L("Open Here"))
            submenu.autoenablesItems = false

            for app in activeOpenHereApps {
                let item = NSMenuItem(title: app.displayName, action: #selector(openHere(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = true
                item.tag = nextActionTag()
                pendingOpenHereActions[item.tag] = PendingOpenHereAction(
                    app: app,
                    directory: openHereDirectory,
                    allowsNonFinderFrontmost: isDesktopException,
                    createdAt: Date()
                )
                submenu.addItem(item)
            }

            openHereItem.submenu = submenu
            mainMenu.addItem(openHereItem)
        }

        if !activeShortcutLocations.isEmpty {
            let shortcutItem = NSMenuItem(title: L("Go To"), action: nil, keyEquivalent: "")
            shortcutItem.isEnabled = true

            let submenu = NSMenu(title: L("Go To"))
            submenu.autoenablesItems = false

            for location in activeShortcutLocations {
                let item = NSMenuItem(title: location.resolvedDisplayName, action: #selector(openShortcutLocation(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = true
                item.tag = nextActionTag()
                pendingShortcutActions[item.tag] = PendingShortcutAction(
                    location: location,
                    createdAt: Date()
                )
                submenu.addItem(item)
            }

            shortcutItem.submenu = submenu
            mainMenu.addItem(shortcutItem)
        }

        if !activeDevToolActions.isEmpty {
            let devToolsItem = NSMenuItem(title: L("Dev Tools"), action: nil, keyEquivalent: "")
            devToolsItem.isEnabled = true

            let submenu = NSMenu(title: L("Dev Tools"))
            submenu.autoenablesItems = false

            for action in activeDevToolActions {
                let item = NSMenuItem(title: action.menuTitle, action: #selector(copyDevToolValue(_:)), keyEquivalent: "")
                item.target = self
                item.isEnabled = true
                item.tag = nextActionTag()
                pendingDevToolActions[item.tag] = PendingDevToolAction(
                    action: action,
                    targets: devToolTargets,
                    allowsNonFinderFrontmost: isDesktopException,
                    createdAt: Date()
                )
                submenu.addItem(item)
            }

            devToolsItem.submenu = submenu
            mainMenu.addItem(devToolsItem)
        }

        guard mainMenu.items.isEmpty == false else {
            recordDiagnostic("menu rejected kind=\(kindDescription) reason=no-enabled-actions")
            return nil
        }

        return mainMenu
    }

    @objc func openHere(_ sender: NSMenuItem) {
        let frontmostIdentifier = frontmostApplicationIdentifier
        let finderFrontmost = frontmostIdentifier == "com.apple.finder"

        guard let action = pendingOpenHereActions.removeValue(forKey: sender.tag) else {
            recordDiagnostic("open-here rejected reason=missing-menu-context tag=\(sender.tag)")
            return
        }

        guard finderFrontmost || action.allowsNonFinderFrontmost else {
            recordDiagnostic("open-here rejected reason=finder-not-frontmost app=\(action.app.rawValue)")
            return
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: action.directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            recordDiagnostic(
                "open-here rejected reason=directory-unavailable app=\(action.app.rawValue) "
                    + "target=\(diagnosticPath(action.directory))"
            )
            return
        }

        recordDiagnostic(
            "open-here accepted app=\(action.app.rawValue) target=\(diagnosticPath(action.directory))"
        )
        openApp(action.app, at: action.directory)
    }

    @objc func openShortcutLocation(_ sender: NSMenuItem) {
        guard let action = pendingShortcutActions.removeValue(forKey: sender.tag) else {
            recordDiagnostic("shortcut rejected reason=missing-menu-context tag=\(sender.tag)")
            return
        }

        let location = action.location.normalized()
        SharedDefaults.requestShortcutOpen(location)
        launchContainingAppForShortcutRequest()
        recordDiagnostic(
            "shortcut requested app-open name=\(location.displayName) "
                + "path=\(location.expandedPath)"
        )
    }

    @objc func copyDevToolValue(_ sender: NSMenuItem) {
        let frontmostIdentifier = frontmostApplicationIdentifier
        let finderFrontmost = frontmostIdentifier == "com.apple.finder"

        guard let pending = pendingDevToolActions.removeValue(forKey: sender.tag) else {
            recordDiagnostic("dev-tool rejected reason=missing-menu-context tag=\(sender.tag)")
            return
        }

        guard finderFrontmost || pending.allowsNonFinderFrontmost else {
            recordDiagnostic("dev-tool rejected reason=finder-not-frontmost action=\(pending.action.rawValue)")
            return
        }

        guard let text = DevToolAction.clipboardText(for: pending.action, targets: pending.targets) else {
            recordDiagnostic(
                "dev-tool rejected reason=empty-result action=\(pending.action.rawValue) "
                    + "targets=\(pending.targets.count)"
            )
            return
        }

        NSPasteboard.general.clearContents()
        let didCopy = NSPasteboard.general.setString(text, forType: .string)
        recordDiagnostic(
            "dev-tool \(didCopy ? "succeeded" : "failed") action=\(pending.action.rawValue) "
                + "targets=\(pending.targets.count) lines=\(text.split(whereSeparator: \.isNewline).count)"
        )
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

    private func openHereTargetDirectory(
        for menuKind: FIMenuKind,
        targetedURL: URL?,
        selectedURLs: [URL]?
    ) -> URL? {
        if menuKind == .contextualMenuForContainer {
            guard let targetedURL else { return nil }
            return directoryURL(for: targetedURL)
        }

        guard menuKind == .contextualMenuForItems,
              let selectedURLs,
              selectedURLs.count == 1,
              let selectedURL = selectedURLs.first,
              isDirectoryURL(selectedURL) else {
            return nil
        }

        return selectedURL
    }

    private func devToolTargets(
        for menuKind: FIMenuKind,
        targetedURL: URL?,
        selectedURLs: [URL]?
    ) -> [URL] {
        // Right-clicking blank space describes the folder currently shown in Finder;
        // right-clicking items describes the selection itself, not its enclosing folder.
        if menuKind == .contextualMenuForContainer {
            guard let targetedURL else { return [] }
            return [targetedURL]
        }

        guard menuKind == .contextualMenuForItems,
              let selectedURLs,
              !selectedURLs.isEmpty else {
            return []
        }

        return selectedURLs
    }

    private func isDirectoryURL(_ url: URL) -> Bool {
        if url.hasDirectoryPath {
            return true
        }

        do {
            return try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        } catch {
            return false
        }
    }

    private func openApp(_ app: OpenHereApp, at directory: URL) {
        guard let applicationURL = app.installedApplicationURL() else {
            recordDiagnostic("open-here failed reason=app-missing app=\(app.rawValue)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [directory],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { _, error in
            if let error {
                self.recordDiagnostic(
                    "open-here failed app=\(app.rawValue) target=\(self.diagnosticPath(directory)) "
                        + "error=\(error.localizedDescription)"
                )
            } else {
                self.recordDiagnostic(
                    "open-here succeeded app=\(app.rawValue) target=\(self.diagnosticPath(directory))"
                )
            }
        }
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

    private func launchContainingAppForShortcutRequest() {
        if let url = URL(string: "righthere://open-shortcut") {
            let didOpenURL = NSWorkspace.shared.open(url)
            recordDiagnostic("shortcut app-url requested opened=\(didOpenURL)")
            if didOpenURL {
                return
            }
        }

        guard let appURL = containingAppURL() else {
            recordDiagnostic("shortcut app-launch failed reason=missing-containing-app")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { [weak self] _, error in
            if let error {
                self?.recordDiagnostic("shortcut app-launch failed error=\(error.localizedDescription)")
            } else {
                self?.recordDiagnostic("shortcut app-launch requested app=\(appURL.path)")
            }
        }
    }

    private func containingAppURL() -> URL? {
        var url = Bundle.main.bundleURL
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }

        return url.pathExtension == "app" ? url : nil
    }
}
