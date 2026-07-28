import AppKit
import SwiftUI

@main
struct RightHereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let githubOwner = "LimeBits"
    private let githubRepo = "RightHere"
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        observeExtensionActivity()
        configureStatusItem()
    }

    deinit {
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

        SharedDefaults.requestExtensionDiagnosticSnapshot()
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

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "RightHere")
        statusItem.button?.imagePosition = .imageOnly

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "打开模板文件夹", action: #selector(openTemplatesDirectory), keyEquivalent: ""))
        if shouldShowExtensionSettingsMenuItem {
            menu.addItem(NSMenuItem(title: "打开扩展设置", action: #selector(openExtensionSettings), keyEquivalent: ""))
        }
        menu.addItem(buildHelpMenuItem())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 RightHere", action: #selector(quit), keyEquivalent: "q"))

        assignTargets(in: menu)

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    private func buildHelpMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "帮助与反馈", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        submenu.addItem(NSMenuItem(title: "检查更新...", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "u"))
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "反馈问题...", action: #selector(openFeedbackIssue), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "打开项目主页", action: #selector(openProjectHome), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "打开 GitHub Issues", action: #selector(openGitHubIssues), keyEquivalent: ""))
        submenu.addItem(NSMenuItem(title: "复制诊断信息", action: #selector(copyDiagnosticInfo), keyEquivalent: ""))

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
                .frame(minWidth: 500, minHeight: 410)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "RightHere 设置"
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
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let urlString: String
        if majorVersion >= 13 {
            urlString = "x-apple.systempreferences:com.apple.ExtensionsPreferences"
        } else {
            urlString = "x-apple.systempreferences:com.apple.preferences.extensions"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func checkForUpdatesFromMenu() {
        checkForUpdates(isManual: true)
    }

    @objc private func openFeedbackIssue() {
        openGitHubIssue(
            title: "反馈：",
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
        alert.messageText = "诊断信息已复制"
        alert.informativeText = "可以直接粘贴到 GitHub Issue 中。诊断信息不包含模板正文或用户文件内容。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private var shouldShowExtensionSettingsMenuItem: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 15
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
                        self.showUpdateErrorAlert(message: "无法连接到 GitHub Releases。请稍后再试，或直接打开项目页面查看。")
                    }
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                if isManual {
                    DispatchQueue.main.async {
                        self.showUpdateErrorAlert(message: "暂时没有读取到有效的 GitHub Release 信息。")
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
                        self.showUpdateErrorAlert(message: "暂时没有读取到有效的 GitHub Release 信息。")
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
                        self.showUpdateErrorAlert(message: "更新信息解析失败，请稍后再试。")
                    }
                }
            }
        }.resume()
    }

    private func showUpdateAvailableAlert(tagName: String, releaseName: String, releaseBody: String, htmlURLString: String) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(tagName)"
        let summary = releaseBody.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSummary = summary.count > 600 ? String(summary.prefix(600)) + "..." : summary
        alert.informativeText = "当前版本：\(currentAppVersion())\n最新版本：\(releaseName)\n\n\(trimmedSummary)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开下载页面")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            openURL(htmlURLString)
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "当前已是最新版本"
        alert.informativeText = "RightHere \(currentAppVersion()) 已经是 GitHub Releases 上的最新版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func showNoReleaseAlert() {
        let alert = NSAlert()
        alert.messageText = "暂时没有可用更新"
        alert.informativeText = "还没有读取到 RightHere 的正式 GitHub Release。首次发布后，检查更新会根据 Releases 里的版本号判断是否有新版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开项目发布页")
        alert.addButton(withTitle: "好的")

        if alert.runModal() == .alertFirstButtonReturn {
            openURL("https://github.com/\(githubOwner)/\(githubRepo)/releases")
        }
    }

    private func showUpdateErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "检查更新失败"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "打开项目发布页")
        alert.addButton(withTitle: "好的")

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
