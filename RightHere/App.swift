import AppKit
import Carbon
import Sparkle
import SwiftUI

@main
struct RightHereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
                .onOpenURL { url in
                    appDelegate.handleIncomingURL(url)
                }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let githubOwner = "LimeBits"
    private let githubRepo = "RightHere"
    private let updaterController = RightHereUpdater.shared.controller
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FinderExtensionBootstrap.ensureRegisteredAndEnabled()
        observeExtensionActivity()
        observeIncomingURLs()
        consumePendingShortcutOpenRequest()
        configureStatusItem()
        observeLanguageChanges()
        openSettingsOnFirstLaunch()
    }

    /// 首次启动时自动打开设置窗口，让用户知道 App 已成功运行。
    /// 之后的每次启动不再自动打开，由用户通过状态栏图标主动触发。
    private func openSettingsOnFirstLaunch() {
        let key = "hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        // 延迟 100ms 确保启动时屏幕上下文已就绪，
        // center() 会把窗口放在屏幕顶部往下三分之一处（偏上但不置顶）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.openSettings()
        }
    }

    private func observeLanguageChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredLanguageChanged),
            name: SharedDefaults.preferredLanguageDidChangeNotificationName,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        consumePendingShortcutOpenRequest()
    }

    deinit {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        DistributedNotificationCenter.default().removeObserver(self)
    }

    private func observeExtensionActivity() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(extensionDidBecomeActive(_:)),
            name: SharedDefaults.extensionDidBecomeActiveNotificationName,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(extensionDiagnosticReceived(_:)),
            name: SharedDefaults.extensionDiagnosticNotificationName,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(extensionDiagnosticSnapshotReceived(_:)),
            name: SharedDefaults.extensionDiagnosticSnapshotNotificationName,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(shortcutOpenRequested(_:)),
            name: SharedDefaults.shortcutOpenRequestNotificationName,
            object: nil
        )

        SharedDefaults.requestExtensionDiagnosticSnapshot()
    }

    private func observeIncomingURLs() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        handleIncomingURL(url)
    }

    @objc private func extensionDidBecomeActive(_ notification: Notification) {
        SharedDefaults.recordExtensionActiveLocally()
    }

    @objc private func extensionDiagnosticReceived(_ notification: Notification) {
        guard let record = SharedDefaults.diagnosticRecord(from: notification) else { return }
        SharedDefaults.mergeExtensionDiagnosticsLocally([record])
    }

    @objc private func extensionDiagnosticSnapshotReceived(_ notification: Notification) {
        SharedDefaults.mergeExtensionDiagnosticsLocally(
            SharedDefaults.diagnosticRecords(from: notification)
        )
    }

    @objc private func shortcutOpenRequested(_ notification: Notification) {
        guard let request = SharedDefaults.shortcutOpenRequest(from: notification) else { return }
        openShortcutLocation(from: request)
        SharedDefaults.clearPendingShortcutOpenRequest(id: request.id)
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme == "righthere" else { return }

        switch url.host {
        case "open-shortcut":
            consumePendingShortcutOpenRequest()
        default:
            break
        }
    }

    private func consumePendingShortcutOpenRequest() {
        guard let request = SharedDefaults.consumePendingShortcutOpenRequest() else { return }
        openShortcutLocation(from: request)
    }

    private func openShortcutLocation(from request: ShortcutOpenRequest) {
        let location = request.location.normalized()
        let didOpen = NSWorkspace.shared.open(location.url)
        SharedDefaults.recordExtensionDiagnostic(
            "app-open-shortcut name=\(location.displayName) path=\(location.expandedPath) opened=\(didOpen)"
        )
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = makeStatusBarIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.menu = buildStatusMenu()
        self.statusItem = statusItem
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L("Open Settings"), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: L("Open Templates Folder"), action: #selector(openTemplatesDirectory), keyEquivalent: ""))
        menu.addItem(buildHelpMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L("Quit RightHere"), action: #selector(quit), keyEquivalent: "q"))

        assignTargets(in: menu)
        return menu
    }

    /// The status-bar menu and the window title are built once, so they keep the
    /// previous language until they are rebuilt. The settings window itself is
    /// SwiftUI and redraws on its own when the selection changes.
    @objc private func preferredLanguageChanged() {
        statusItem?.menu = buildStatusMenu()
        settingsWindow?.title = L("RightHere Settings")
    }

    private func makeStatusBarIcon() -> NSImage? {
        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        guard let symbol = NSImage(
            systemSymbolName: "doc.badge.plus",
            accessibilityDescription: "RightHere"
        )?.withSymbolConfiguration(symbolConfiguration) else {
            return nil
        }

        let canvasSize = NSSize(width: 18, height: 18)
        let image = NSImage(size: canvasSize)
        image.lockFocus()
        symbol.draw(
            in: NSRect(x: 0, y: 0.25, width: canvasSize.width, height: canvasSize.height),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func buildHelpMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L("Help & Feedback"), action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(NSMenuItem(title: L("Check for Updates…"), action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u"))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: L("Report an Issue…"), action: #selector(openFeedbackIssue), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: L("Open Project Home"), action: #selector(openProjectHome), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: L("Open GitHub Issues"), action: #selector(openGitHubIssues), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: L("Copy Diagnostic Info"), action: #selector(copyDiagnosticInfo), keyEquivalent: ""))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: L("Open Extension Settings"), action: #selector(openExtensionSettings), keyEquivalent: ""))

        item.submenu = submenu
        return item
    }

    private func assignTargets(in menu: NSMenu) {
        for item in menu.items {
            if item.action != nil {
                item.target = self
            }

            if let submenu = item.submenu {
                assignTargets(in: submenu)
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let contentView = ContentView()
                .frame(minWidth: 560, minHeight: 500)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = L("RightHere Settings")
            window.contentViewController = NSHostingController(rootView: contentView)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openTemplatesDirectory() {
        TemplateAssets.initializeDefaultTemplates()
        SharedDefaults.refreshTemplateCacheFromDisk()
        if let url = SharedDefaults.templatesDirectoryURL {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openExtensionSettings() {
        FinderExtensionInspector.openExtensionSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func checkForUpdatesFromMenu() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    @objc private func openFeedbackIssue() {
        openGitHubIssue(
            title: L("Feedback: "),
            body: """
            ## 问题描述


            ## 复现步骤
            1.
            2.
            3.

            ## 期望结果


            ## 诊断信息
            ```text
            \(diagnosticSummary())
            ```
            """,
            labels: "bug"
        )
    }

    @objc private func openProjectHome() {
        openURL("https://github.com/\(githubOwner)/\(githubRepo)")
    }

    @objc private func openGitHubIssues() {
        openURL("https://github.com/\(githubOwner)/\(githubRepo)/issues")
    }

    @objc private func copyDiagnosticInfo() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticSummary(), forType: .string)

        let alert = NSAlert()
        alert.messageText = L("Diagnostics Copied")
        alert.informativeText = L("You can paste this straight into a GitHub issue. Diagnostics do not include template contents or your file contents.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("OK"))
        alert.runModal()
    }

    private func checkForUpdates(isManual: Bool) {
        guard let url = URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("RightHere/\(currentAppVersion())", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if error != nil {
                if isManual {
                    DispatchQueue.main.async {
                        self.showUpdateErrorAlert(message: L("Could not reach GitHub Releases. Try again later, or open the project page directly."))
                    }
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                if isManual {
                    DispatchQueue.main.async {
                        self.showUpdateErrorAlert(message: L("No valid GitHub Release information was returned."))
                    }
                }
                return
            }

            guard httpResponse.statusCode != 404 else {
                if isManual {
                    DispatchQueue.main.async {
                        self.showNoReleaseAlert()
                    }
                }
                return
            }

            guard httpResponse.statusCode == 200, let data else {
                if isManual {
                    DispatchQueue.main.async {
                        self.showUpdateErrorAlert(message: L("No valid GitHub Release information was returned."))
                    }
                }
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    throw NSError(domain: "RightHere.Update", code: 1)
                }

                let releaseName = json["name"] as? String ?? tagName
                let releaseBody = json["body"] as? String ?? ""
                let htmlURLString = json["html_url"] as? String ?? "https://github.com/\(self.githubOwner)/\(self.githubRepo)/releases/latest"
                let latestVersion = self.normalizedVersion(tagName)
                let currentVersion = self.normalizedVersion(self.currentAppVersion())

                DispatchQueue.main.async {
                    if self.compareVersions(latestVersion, currentVersion) == .orderedDescending {
                        self.showUpdateAvailableAlert(tagName: tagName, releaseName: releaseName, releaseBody: releaseBody, htmlURLString: htmlURLString)
                    } else if isManual {
                        self.showNoUpdateAlert()
                    }
                }
            } catch {
                if isManual {
                    DispatchQueue.main.async {
                        self.showUpdateErrorAlert(message: L("Could not parse the update information. Try again later."))
                    }
                }
            }
        }.resume()
    }

    private func showUpdateAvailableAlert(tagName: String, releaseName: String, releaseBody: String, htmlURLString: String) {
        let alert = NSAlert()
        alert.messageText = L("New version available: %@", tagName)
        let summary = releaseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.count > 600 ? String(summary.prefix(600)) + "..." : summary
        alert.informativeText = L("Current version: %1$@\nLatest version: %2$@\n\n%3$@", currentAppVersion(), releaseName, trimmedSummary)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("Open Download Page"))
        alert.addButton(withTitle: L("Later"))

        if alert.runModal() == .alertFirstButtonReturn {
            openURL(htmlURLString)
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = L("You are up to date")
        alert.informativeText = L("RightHere %@ is the latest version on GitHub Releases.", currentAppVersion())
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("OK"))
        alert.runModal()
    }

    private func showNoReleaseAlert() {
        let alert = NSAlert()
        alert.messageText = L("No updates available yet")
        alert.informativeText = L("No stable GitHub Release has been published for RightHere yet. After the first release, update checks compare version numbers from Releases.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("Open Releases Page"))
        alert.addButton(withTitle: L("OK"))

        if alert.runModal() == .alertFirstButtonReturn {
            openURL("https://github.com/\(githubOwner)/\(githubRepo)/releases")
        }
    }

    private func showUpdateErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = L("Update check failed")
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("Open Releases Page"))
        alert.addButton(withTitle: L("OK"))

        if alert.runModal() == .alertFirstButtonReturn {
            openURL("https://github.com/\(githubOwner)/\(githubRepo)/releases")
        }
    }

    private func normalizedVersion(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rightParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(leftParts.count, rightParts.count)

        for index in 0..<count {
            let left = index < leftParts.count ? leftParts[index] : 0
            let right = index < rightParts.count ? rightParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }

        return .orderedSame
    }

    private func openGitHubIssue(title: String, body: String, labels: String) {
        var components = URLComponents(string: "https://github.com/\(githubOwner)/\(githubRepo)/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: labels)
        ]

        if let url = components?.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func diagnosticSummary() -> String {
        let version = currentAppVersion()
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let architecture: String
        #if arch(arm64)
        architecture = "arm64"
        #elseif arch(x86_64)
        architecture = "x86_64"
        #else
        architecture = "unknown"
        #endif

        let availableTemplates = SharedDefaults.getLocalAvailableFileTemplates()
        let enabledTemplates = SharedDefaults.getLocalEnabledFileTemplates()
        let diagnosticRecords = SharedDefaults.getLocalExtensionDiagnostics()
        let lastActiveDescription: String
        if let lastActive = SharedDefaults.getExtensionLastActive() {
            let seconds = Int(Date().timeIntervalSince(lastActive))
            lastActiveDescription = "\(seconds)s ago"
        } else {
            lastActiveDescription = "never"
        }

        let diagnosticLog: String
        if diagnosticRecords.isEmpty {
            diagnosticLog = "No extension diagnostics captured"
        } else {
            let formatter = ISO8601DateFormatter()
            diagnosticLog = diagnosticRecords.map { record in
                "[\(formatter.string(from: record.timestamp))] \(record.message)"
            }.joined(separator: "\n")
        }

        return """
        RightHere version: \(version) (\(build))
        macOS: \(osVersion)
        Architecture: \(architecture)
        Language: \(SharedDefaults.getPreferredLanguage().diagnosticDescription)
        Extension last response: \(lastActiveDescription)
        Templates: \(enabledTemplates.count) enabled / \(availableTemplates.count) available
        Enabled extensions: \(enabledTemplates.map { $0.fileExtension }.joined(separator: ", "))
        Templates directory: \(SharedDefaults.templatesDirectoryURL?.path ?? "unavailable")

        Recent extension diagnostics:
        \(diagnosticLog)
        """
    }

    private func currentAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

}

final class RightHereUpdater {
    static let shared = RightHereUpdater()

    let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // 首次安装时 Sparkle 没有存过偏好值，显式设为 true 确保自动检查更新默认开启。
        // 用户在设置页关闭后 Sparkle 会持久化其选择，后续启动不会被这里覆盖。
        let updatesKey = "SUEnableAutomaticChecks"
        if UserDefaults.standard.object(forKey: updatesKey) == nil {
            controller.updater.automaticallyChecksForUpdates = true
        }
        
        #if DEBUG
        // Debug builds get an empty SUPublicEDKey (the real key is injected only by
        // Scripts/package-developer-id.sh), and SURequireSignedFeed is on, so any
        // scheduled check fails with "无法启动更新程序". Manual checks still run.
        // 覆盖上面的默认值，强制关闭自动检查（即使用户之前开过）。
        controller.updater.automaticallyChecksForUpdates = false
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            controller.updater.automaticallyChecksForUpdates
        }
        set {
            #if DEBUG
            // Keep scheduled checks off in Debug even if the settings toggle is flipped.
            _ = newValue
            #else
            controller.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }
}

enum FinderExtensionBootstrap {
    private static let extensionBundleIdentifier = "com.LimeBits.RightHere.Extension"
    private static let finderSyncPointIdentifier = "com.apple.FinderSync"
    private static let oldBundleIdentifiers = [
        "com.b-vibe.RightHere.Extension",
        "com.b-vibe.RightHere.FinderSync"
    ]

    static func ensureRegisteredAndEnabled() {
        DispatchQueue.global(qos: .utility).async {
            registerAppWithLaunchServices()
            oldBundleIdentifiers.forEach { runPlugInKit(arguments: ["-e", "ignore", "-i", $0]) }

            let initialStatus = waitForRegistration()
            runPlugInKit(arguments: ["-e", "use", "-i", extensionBundleIdentifier])

            guard let enabledStatus = waitForEnabledStatus() else {
                NSLog("RightHere: Finder extension bootstrap did not verify enabled status. initial=%@", initialStatus ?? "<none>")
                return
            }

            if initialStatus?.hasPrefix("+") != true && enabledStatus.hasPrefix("+") {
                restartFinder()
            }
        }
    }

    private static func registerAppWithLaunchServices() {
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
        )
        process.arguments = ["-f", "-R", "-trusted", Bundle.main.bundlePath]
        try? process.run()
        process.waitUntilExit()
    }

    @discardableResult
    private static func runPlugInKit(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return 1
        }
    }

    private static func waitForRegistration() -> String? {
        for _ in 0..<10 {
            if let status = extensionStatusLine() {
                return status
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    private static func waitForEnabledStatus() -> String? {
        for _ in 0..<8 {
            if let status = extensionStatusLine(), status.hasPrefix("+") {
                return status
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return extensionStatusLine()
    }

    private static func extensionStatusLine() -> String? {
        let output = runPlugInKitWithOutput(arguments: ["-m", "-p", finderSyncPointIdentifier, "-A", "-D"])
        return output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.contains(extensionBundleIdentifier) }
    }

    private static func runPlugInKitWithOutput(arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func restartFinder() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Finder"]
        try? process.run()
        process.waitUntilExit()
    }
}
