import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    private var enabledTypes: [FileType] = []

    override init() {
        super.init()

        NSLog("RightHereExtension: Initializing Finder Sync Extension")

        // Use getpwuid to get the real home directory (FileManager returns sandboxed paths inside container)
        var watchedURLs: Set<URL> = []
        if let pw = getpwuid(getuid()) {
            let realHome = String(cString: pw.pointee.pw_dir)
            let homeURL = URL(fileURLWithPath: realHome)
            watchedURLs.insert(homeURL)
            for sub in ["Desktop", "Documents", "Downloads", "Music", "Pictures", "Movies"] {
                watchedURLs.insert(homeURL.appendingPathComponent(sub))
            }
        }
        FIFinderSyncController.default().directoryURLs = watchedURLs
        NSLog("RightHereExtension: watching directories: %@", watchedURLs.map { $0.path }.joined(separator: ", "))

        loadSettings()

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(settingsChanged),
            name: Notification.Name("com.b-vibe.RightHere.SettingsChanged"),
            object: nil
        )
    }

    @objc private func settingsChanged() {
        loadSettings()
    }

    private func loadSettings() {
        enabledTypes = SharedDefaults.getEnabledFileTypes()
    }

    private func updateHeartbeat() {
        if let defaults = SharedDefaults.sharedSuite {
            defaults.set(Date(), forKey: "extensionLastActive")
            defaults.synchronize()
        }
    }

    // MARK: - Finder Sync Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        updateHeartbeat()

        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else { return nil }

        let activeTypes = enabledTypes
        guard !activeTypes.isEmpty else { return nil }

        let mainMenu = NSMenu(title: "")
        let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "新建文件")

        for (index, type) in activeTypes.enumerated() {
            let item = NSMenuItem(title: type.displayName, action: #selector(createNewFile(_:)), keyEquivalent: "")
            item.tag = index
            submenu.addItem(item)
        }

        newFileItem.submenu = submenu
        mainMenu.addItem(newFileItem)
        return mainMenu
    }

    @objc func createNewFile(_ sender: NSMenuItem) {
        NSLog("RightHereExtension: createNewFile called, tag=%d", sender.tag)
        let activeTypes = enabledTypes
        guard sender.tag >= 0, sender.tag < activeTypes.count else {
            NSLog("RightHereExtension: invalid tag %d, activeTypes count=%d", sender.tag, activeTypes.count)
            return
        }
        let type = activeTypes[sender.tag]

        // Determine destination directory
        let targetDir: URL
        if let targeted = FIFinderSyncController.default().targetedURL() {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: targeted.path, isDirectory: &isDir), isDir.boolValue {
                targetDir = targeted
            } else {
                targetDir = targeted.deletingLastPathComponent()
            }
        } else if let selected = FIFinderSyncController.default().selectedItemURLs()?.first {
            targetDir = selected.deletingLastPathComponent()
        } else {
            NSLog("RightHereExtension: could not determine target directory")
            return
        }

        NSLog("RightHereExtension: target directory: %@", targetDir.path)

        // Ensure template exists
        guard let templatesDir = SharedDefaults.templatesDirectoryURL else {
            NSLog("RightHereExtension: templates directory URL is nil")
            return
        }
        let templateURL = templatesDir.appendingPathComponent("template.\(type.fileExtension)")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: templateURL.path) {
            TemplateAssets.initializeDefaultTemplates()
            guard fileManager.fileExists(atPath: templateURL.path) else {
                NSLog("RightHereExtension: template missing after re-init: %@", templateURL.path)
                return
            }
        }

        // Find a non-colliding destination name
        var destinationURL = targetDir.appendingPathComponent("\(type.defaultFileName).\(type.fileExtension)")
        var count = 2
        while fileManager.fileExists(atPath: destinationURL.path) {
            destinationURL = targetDir.appendingPathComponent("\(type.defaultFileName) (\(count)).\(type.fileExtension)")
            count += 1
        }

        // Copy template to destination
        do {
            try fileManager.copyItem(at: templateURL, to: destinationURL)
            NSLog("RightHereExtension: created file at %@", destinationURL.path)
        } catch {
            NSLog("RightHereExtension: failed to create file: %@", error.localizedDescription)
        }
    }
}
