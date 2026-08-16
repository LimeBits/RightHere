import Foundation
import ServiceManagement

/// Manages RightHere's user-controlled launch-at-login registration.
///
/// `SMAppService` is the supported mechanism on macOS 13 and later. Earlier
/// supported systems use a per-user LaunchAgent so macOS 11 and 12 retain the
/// same setting without requiring a privileged helper or administrator access.
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let label = "com.LimeBits.RightHere.launchAtLogin"
    private let initializationKey = "launchAtLoginInitialized"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }

        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func enableByDefaultIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: initializationKey) else { return }

        do {
            try setEnabled(true)
            UserDefaults.standard.set(true, forKey: initializationKey)
        } catch {
            // Do not persist the initialization marker after a failed registration:
            // a later launch can retry when the app is installed in its final location.
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }

        if enabled {
            try installLegacyLaunchAgent()
        } else {
            try removeLegacyLaunchAgent()
        }
    }

    private func installLegacyLaunchAgent() throws {
        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let directoryURL = launchAgentURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let agent: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive"
        ]

        let plistData = try PropertyListSerialization.data(
            fromPropertyList: agent,
            format: .xml,
            options: 0
        )
        try plistData.write(to: launchAgentURL, options: .atomic)
    }

    private func removeLegacyLaunchAgent() throws {
        guard FileManager.default.fileExists(atPath: launchAgentURL.path) else { return }
        try FileManager.default.removeItem(at: launchAgentURL)
    }
}
