import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    private var enabledTemplates: [FileTemplate] = SharedDefaults.defaultFileTemplates
    private var templateRecordsByExtension: [String: TemplateRecord] = Dictionary(
        uniqueKeysWithValues: SharedDefaults.defaultFileTemplates.compactMap { template in
            SharedDefaults.getLocalTemplateRecord(for: template).map { (template.fileExtension, $0) }
        }
    )

    override init() {
        super.init()

        NSLog("RightHereExtension: Initializing Finder Sync Extension")

        configureWatchedDirectories()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsChanged(_:)),
            name: Notification.Name("com.b-vibe.RightHere.SettingsChanged"),
            object: nil
        )
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

    private var isFinderFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
    }

    // MARK: - Finder Sync Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        updateHeartbeat()

        guard isFinderFrontmost else { return nil }
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }
        guard let targetDir = currentTargetDirectory(for: menuKind), isAllowedMenuDirectory(targetDir) else { return nil }

        let activeTemplates = enabledTemplates
        guard !activeTemplates.isEmpty else { return nil }

        let mainMenu = NSMenu(title: "")
        mainMenu.autoenablesItems = false

        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        newFileItem.isEnabled = true

        let submenu = NSMenu(title: "新建文件")
        submenu.autoenablesItems = false

        for (index, template) in activeTemplates.enumerated() {
            let item = NSMenuItem(title: template.displayName, action: #selector(createNewFile(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = true
            item.tag = index
            submenu.addItem(item)
        }

        newFileItem.submenu = submenu
        mainMenu.addItem(newFileItem)
        return mainMenu
    }

    @objc func createNewFile(_ sender: NSMenuItem) {
        NSLog("RightHereExtension: createNewFile called, tag=%d", sender.tag)
        let activeTemplates = enabledTemplates
        guard sender.tag >= 0, sender.tag < activeTemplates.count else {
            NSLog("RightHereExtension: invalid tag %d, activeTemplates count=%d", sender.tag, activeTemplates.count)
            return
        }
        let template = activeTemplates[sender.tag]

        // Determine destination directory
        guard isFinderFrontmost,
              let targetDir = destinationDirectoryForCreate(),
              isAllowedMenuDirectory(targetDir) else {
            NSLog("RightHereExtension: could not determine target directory")
            return
        }

        NSLog("RightHereExtension: target directory: %@", targetDir.path)

        guard let templateRecord = templateRecordsByExtension[template.fileExtension] else {
            NSLog("RightHereExtension: template record missing: %@", template.templateFileName)
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
            NSLog("RightHereExtension: created file at %@", destinationURL.path)
        } catch {
            NSLog("RightHereExtension: failed to create file: %@", error.localizedDescription)
        }
    }

    private func currentTargetDirectory(for menuKind: FIMenuKind) -> URL? {
        if menuKind == .contextualMenuForContainer {
            return FIFinderSyncController.default().targetedURL()
        }

        if let selected = FIFinderSyncController.default().selectedItemURLs()?.first {
            return selected.deletingLastPathComponent()
        }

        return FIFinderSyncController.default().targetedURL()
    }

    private func destinationDirectoryForCreate() -> URL? {
        if let targeted = FIFinderSyncController.default().targetedURL() {
            return directoryURL(for: targeted)
        }

        if let selected = FIFinderSyncController.default().selectedItemURLs()?.first {
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
