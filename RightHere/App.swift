import AppKit
import SwiftUI

@main
struct RightHereApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Initialize default templates in App Groups shared folder
        TemplateAssets.initializeDefaultTemplates()
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
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
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 RightHere", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        self.statusItem = statusItem
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let contentView = ContentView()
                .frame(minWidth: 480, minHeight: 380)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
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

    private var shouldShowExtensionSettingsMenuItem: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion < 15
    }
}
