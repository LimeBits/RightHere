import AppKit
import SwiftUI

struct ContentView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case templates
        case updates
        case advanced

        var id: String { rawValue }

        var title: String {
            switch self {
            case .templates: return "模板"
            case .updates: return "更新"
            case .advanced: return "高级"
            }
        }
    }

    @State private var availableTemplates: [FileTemplate] = []
    @State private var enabledTemplates: Set<FileTemplate> = []
    @State private var selectedTab: SettingsTab = .templates
    @State private var lastFinderCall: Date? = nil
    @State private var extensionRegistrationState: FinderExtensionRegistrationState = .checking
    @State private var automaticallyChecksForUpdates = true
    @State private var isFinderMenuDisabled = false
    @State private var now = Date()
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            settingsTabs

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRecentFinderCall ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                Text(finderCallStatusText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 16)

            Text(appVersionText)
                .lineLimit(1)
                .layoutPriority(1)
        }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 18)
            .frame(minHeight: 38, alignment: .center)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.36))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSettings()
            loadUpdateSettings()
            refreshExistingTemplatesOnFirstOpen()
            checkFinderResponseStatus()
            refreshFinderExtensionRegistration()
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                now = Date()
                checkFinderResponseStatus()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTemplatesFromDiskIfNeeded()
            checkFinderResponseStatus()
            refreshFinderExtensionRegistration(silently: true)
        }
    }

    private var settingsTabs: some View {
        VStack(spacing: 14) {
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)
            .padding(.top, 20)

            Group {
                switch selectedTab {
                case .templates:
                    templateSettingsTab
                case .updates:
                    updateSettingsTab
                case .advanced:
                    advancedSettingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, minHeight: 356)
    }

    private var templateSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自定义模板")
                        .font(.system(size: 14, weight: .semibold))
                    Text("勾选要显示在 Finder 右键菜单中的模板。使用 template.rtf 这样的命名添加模板。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: openTemplatesDirectory) {
                    Label("打开模板文件夹", systemImage: "folder")
                }
                .font(.system(size: 12))

                Button(action: refreshTemplates) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .font(.system(size: 12))
            }

            Divider()

            if availableTemplates.isEmpty {
                emptyTemplatesView
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                VStack(spacing: 10) {
                    if enabledTemplates.isEmpty {
                        disabledTemplatesWarning
                    }

                    TemplateListScrollView {
                        VStack(spacing: 0) {
                            ForEach(availableTemplates) { template in
                                templateRow(template)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 28)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var updateSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            updateSettingsView

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("手动检查")
                        .font(.system(size: 12, weight: .semibold))
                    Text("立即检查 GitHub Release 上的最新正式版本。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: checkForUpdates) {
                    Label("检查更新", systemImage: "magnifyingglass")
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 6) {
                Text("当前版本")
                    .font(.system(size: 12, weight: .semibold))
                Text(appVersionText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("旧版 0.1.10 / 0.1.11 可能无法完成首次自我替换；手动安装 0.1.12 后，后续更新会使用新的 Sparkle 安装权限。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.24))
            .cornerRadius(6)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private var advancedSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            finderExtensionStatusView
            extensionControlView

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "gearshape")
                    .foregroundColor(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("系统扩展设置")
                        .font(.system(size: 12, weight: .semibold))
                    Text("用于排查 Finder 扩展启用状态；不同 macOS 版本可能只打开系统设置主页。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: openSystemExtensionSettings) {
                    Label("打开扩展设置", systemImage: "gearshape")
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
            .cornerRadius(6)

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("诊断信息")
                        .font(.system(size: 12, weight: .semibold))
                    Text("复制版本、模板目录和最近 Finder 调用状态，方便排查。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: copyDiagnostics) {
                    Label("复制诊断", systemImage: "doc.on.doc")
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
            .cornerRadius(6)

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private func templateRow(_ template: FileTemplate) -> some View {
        HStack(spacing: 0) {
            Toggle("", isOn: Binding(
                get: { enabledTemplates.contains(template) },
                set: { isChecked in
                    if isChecked {
                        enabledTemplates.insert(template)
                    } else {
                        enabledTemplates.remove(template)
                    }
                    saveSettings()
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .frame(width: 28, alignment: .leading)

            Image(systemName: getIcon(for: template))
                .font(.system(size: 15))
                .foregroundColor(getIconColor(for: template))
                .frame(width: 22, height: 22)
                .padding(.leading, 10)
                .padding(.trailing, 10)

            Text(template.displayName)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text("没有找到可用模板")
                .font(.system(size: 13, weight: .semibold))

            Text("请打开模板文件夹，添加 template.txt、template.md 或 template.rtf。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var disabledTemplatesWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)

            Text("当前没有启用任何模板，Finder 右键菜单不会显示“新建文件”。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.10))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var finderExtensionStatusView: some View {
        if !extensionRegistrationState.shouldShowStatusBanner {
            EmptyView()
        } else {
            finderExtensionStatusBanner
        }
    }

    private var finderExtensionStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: extensionRegistrationState.symbolName)
                .foregroundColor(extensionRegistrationState.symbolColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(extensionRegistrationState.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(extensionRegistrationState.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: {
                openSystemExtensionSettings()
                refreshFinderExtensionRegistrationAfterDelay()
            }) {
                Label(extensionRegistrationState.settingsButtonTitle, systemImage: "gearshape")
            }
            .font(.system(size: 11))

            Button(action: { refreshFinderExtensionRegistration() }) {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(extensionRegistrationState.backgroundColor)
        .cornerRadius(6)
    }

    private var updateSettingsView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("版本更新")
                    .font(.system(size: 12, weight: .semibold))
                Text("自动检查新版本。仍可从菜单栏手动检查更新。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { automaticallyChecksForUpdates },
                set: { isEnabled in
                    automaticallyChecksForUpdates = isEnabled
                    RightHereUpdater.shared.automaticallyChecksForUpdates = isEnabled
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.48))
        .cornerRadius(6)
    }

    private var extensionControlView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isFinderMenuDisabled ? "power.circle" : "puzzlepiece.extension")
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text("右键菜单")
                    .font(.system(size: 12, weight: .semibold))
                Text(isFinderMenuDisabled ? "RightHere 暂时不会在 Finder 右键菜单中显示。" : "关闭后 Finder 右键菜单里的“新建文件”会消失。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { !isFinderMenuDisabled },
                set: { isEnabled in
                    isFinderMenuDisabled = !isEnabled
                    SharedDefaults.setFinderMenuDisabled(!isEnabled)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
        .cornerRadius(6)
    }

    private func getIcon(for template: FileTemplate) -> String {
        switch template.fileExtension {
        case "txt": return "doc.text"
        case "md": return "arrow.down.doc"
        case "rtf": return "doc.richtext"
        case "docx": return "doc.richtext"
        case "xlsx": return "tablecells"
        case "pptx": return "play.rectangle"
        case "csv": return "tablecells"
        case "json": return "curlybraces"
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
    
    private func getIconColor(for template: FileTemplate) -> Color {
        switch template.fileExtension {
        case "txt": return .secondary
        case "md": return Color(red: 0.18, green: 0.67, blue: 0.73)
        case "rtf", "docx": return .blue
        case "xlsx", "csv": return .green
        case "pptx": return .orange
        case "json", "swift", "py": return .purple
        default: return .secondary
        }
    }
    
    private func loadSettings() {
        let available = SharedDefaults.getAvailableFileTemplates()
        let enabled = SharedDefaults.getEnabledFileTemplates()
        self.availableTemplates = available
        self.enabledTemplates = Set(enabled)
        self.isFinderMenuDisabled = SharedDefaults.isFinderMenuDisabled()
    }

    private func loadUpdateSettings() {
        automaticallyChecksForUpdates = RightHereUpdater.shared.automaticallyChecksForUpdates
    }

    private func checkForUpdates() {
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        RightHereUpdater.shared.controller.checkForUpdates(nil)
    }

    private func copyDiagnostics() {
        let enabled = SharedDefaults.getEnabledFileTemplates()
            .map { $0.fileExtension }
            .sorted()
            .joined(separator: ", ")
        let diagnostics = """
        App: \(appVersionText)
        Finder call: \(finderCallStatusText)
        Finder extension: \(extensionRegistrationState.title)
        Templates directory: \(SharedDefaults.templatesDirectoryURL?.path ?? "unavailable")
        Enabled templates: \(enabled.isEmpty ? "none" : enabled)
        Finder menu: \(SharedDefaults.isFinderMenuDisabled() ? "disabled" : "enabled")
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)

        let alert = NSAlert()
        alert.messageText = "诊断信息已复制"
        alert.informativeText = "诊断信息不包含模板正文或用户文件内容。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    private func refreshExistingTemplatesOnFirstOpen() {
        SharedDefaults.refreshTemplateCacheFromDisk()
        loadSettings()
    }
    
    private func saveSettings() {
        SharedDefaults.setEnabledFileTemplates(Array(enabledTemplates))
    }
    
    private func openSystemExtensionSettings() {
        FinderExtensionInspector.openExtensionSettings()
    }
    
    private func openTemplatesDirectory() {
        TemplateAssets.initializeDefaultTemplates()
        SharedDefaults.refreshTemplateCacheFromDisk()
        loadSettings()
        if let url = SharedDefaults.templatesDirectoryURL {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshTemplates() {
        SharedDefaults.refreshTemplateCacheFromDisk()
        loadSettings()
    }

    private func refreshTemplatesFromDiskIfNeeded() {
        SharedDefaults.refreshTemplateCacheFromDiskIfNeeded()
        loadSettings()
    }

    private func refreshFinderExtensionRegistration(silently: Bool = false) {
        if !silently {
            extensionRegistrationState = .checking
        }

        DispatchQueue.global(qos: .utility).async {
            let state = FinderExtensionInspector.currentRegistrationState()
            DispatchQueue.main.async {
                extensionRegistrationState = state
            }
        }
    }

    private func refreshFinderExtensionRegistrationAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            refreshFinderExtensionRegistration(silently: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            refreshFinderExtensionRegistration(silently: true)
        }
    }
    
    private func checkFinderResponseStatus() {
        lastFinderCall = SharedDefaults.getExtensionLastActive()
    }

    private var isRecentFinderCall: Bool {
        guard let lastFinderCall else { return false }
        return now.timeIntervalSince(lastFinderCall) < 15
    }

    private var finderCallStatusText: String {
        guard let lastFinderCall else {
            return "最近 Finder 调用：尚未检测到"
        }

        let elapsed = max(0, Int(now.timeIntervalSince(lastFinderCall)))

        if elapsed < 10 {
            return "最近 Finder 调用：刚刚"
        }

        if elapsed < 60 {
            return "最近 Finder 调用：\(elapsed) 秒前"
        }

        let minutes = elapsed / 60
        if minutes < 60 {
            return "最近 Finder 调用：\(minutes) 分钟前"
        }

        let hours = minutes / 60
        return "最近 Finder 调用：\(hours) 小时前"
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知版本"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, !build.isEmpty {
            return "RightHere \(version) (\(build))"
        }

        return "RightHere \(version)"
    }
}

private struct TemplateListScrollView<Content: View>: NSViewRepresentable {
    @ViewBuilder var content: Content

    func makeNSView(context: Context) -> NSScrollView {
        TemplateListScrollContainer(rootView: content)
    }

    func updateNSView(_ container: NSScrollView, context: Context) {
        guard let container = container as? TemplateListScrollContainer<Content> else { return }
        container.update(rootView: content)
    }
}

private final class TemplateListScrollContainer<Content: View>: NSScrollView {
    private let thumbView = NSView()
    private var hostingView: NSHostingView<Content>
    private var trackingArea: NSTrackingArea?
    private var isHovering = false

    init(rootView: Content) {
        self.hostingView = NSHostingView(rootView: rootView)
        super.init(frame: .zero)

        drawsBackground = false
        hasVerticalScroller = false
        hasHorizontalScroller = false
        autohidesScrollers = true
        borderType = .noBorder

        contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollPositionChanged),
            name: NSView.boundsDidChangeNotification,
            object: contentView
        )

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        documentView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
        ])

        thumbView.wantsLayer = true
        thumbView.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.32).cgColor
        thumbView.layer?.cornerRadius = 2.5
        thumbView.alphaValue = 0
        addSubview(thumbView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func update(rootView: Content) {
        hostingView.rootView = rootView
        needsLayout = true
        updateThumb()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateThumb()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateThumb()
    }

    override func layout() {
        super.layout()
        updateThumb()
    }

    @objc private func scrollPositionChanged() {
        updateThumb()
    }

    private func updateThumb() {
        guard let documentView else {
            thumbView.alphaValue = 0
            return
        }

        let visibleHeight = contentView.bounds.height
        let documentHeight = documentView.bounds.height
        guard documentHeight > visibleHeight + 1 else {
            thumbView.alphaValue = 0
            return
        }

        let trackInset: CGFloat = 6
        let thumbWidth: CGFloat = 5
        let trackHeight = max(0, bounds.height - trackInset * 2)
        let thumbHeight = max(28, trackHeight * visibleHeight / documentHeight)
        let maxOffset = max(1, documentHeight - visibleHeight)
        let visibleY = contentView.documentVisibleRect.origin.y
        let progress = min(max(visibleY / maxOffset, 0), 1)
        let travel = max(0, trackHeight - thumbHeight)
        let thumbY = trackInset + travel * progress

        thumbView.frame = CGRect(
            x: bounds.width - thumbWidth - 4,
            y: thumbY,
            width: thumbWidth,
            height: thumbHeight
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            thumbView.animator().alphaValue = isHovering ? 1 : 0
        }
    }
}

enum FinderExtensionRegistrationState: Equatable {
    case checking
    case enabled(String)
    case disabled(String)
    case notRegistered
    case unavailable(String)

    var title: String {
        switch self {
        case .checking:
            return "Finder 扩展状态：正在检查"
        case .enabled:
            return "Finder 扩展状态：已启用"
        case .disabled:
            return "Finder 扩展状态：未启用"
        case .notRegistered:
            return "Finder 扩展状态：系统未发现 RightHere"
        case .unavailable:
            return "Finder 扩展状态：暂时不可读"
        }
    }

    var message: String {
        switch self {
        case .checking:
            return "正在读取系统扩展注册状态。"
        case .enabled:
            return "如果右键菜单仍未出现，请在 Finder 中打开用户目录后右键空白处。"
        case .disabled:
            return "请在系统设置中启用 RightHere 的 Finder 扩展。"
        case .notRegistered:
            return "当前安装包可能未正确签名，或系统尚未注册内嵌扩展。"
        case .unavailable(let detail):
            return detail
        }
    }

    var launchAlertMessage: String {
        switch self {
        case .disabled:
            return "RightHere 已安装，但 Finder 扩展还没有启用。请在系统设置中启用 RightHere，然后重启 Finder。"
        case .notRegistered:
            return "RightHere 已安装，但系统没有发现它的 Finder 扩展。常见原因是安装了未签名/跳过签名的测试包。请换用已签名安装包，或用自己的 Apple Developer 账号重新构建。"
        case .unavailable(let detail):
            return "RightHere 暂时无法读取 Finder 扩展状态。\n\n\(detail)"
        case .checking, .enabled:
            return ""
        }
    }

    var shouldAlertOnLaunch: Bool {
        switch self {
        case .disabled, .notRegistered:
            return true
        case .checking, .enabled, .unavailable:
            return false
        }
    }

    var shouldShowStatusBanner: Bool {
        switch self {
        case .disabled, .notRegistered:
            return true
        case .checking, .enabled, .unavailable:
            return false
        }
    }

    var settingsButtonTitle: String {
        switch self {
        case .disabled, .notRegistered:
            return "扩展设置"
        case .checking, .enabled, .unavailable:
            return "打开扩展"
        }
    }

    var symbolName: String {
        switch self {
        case .checking:
            return "clock"
        case .enabled:
            return "checkmark.circle.fill"
        case .disabled:
            return "exclamationmark.circle.fill"
        case .notRegistered:
            return "xmark.circle.fill"
        case .unavailable:
            return "info.circle.fill"
        }
    }

    var symbolColor: Color {
        switch self {
        case .checking:
            return .secondary
        case .enabled:
            return .green
        case .disabled:
            return .orange
        case .notRegistered:
            return .red
        case .unavailable:
            return .secondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .enabled:
            return Color.green.opacity(0.10)
        case .disabled:
            return Color.orange.opacity(0.10)
        case .notRegistered:
            return Color.red.opacity(0.10)
        case .unavailable:
            return Color.secondary.opacity(0.08)
        case .checking:
            return Color.secondary.opacity(0.08)
        }
    }
}

enum FinderExtensionInspector {
    static let extensionBundleIdentifier = "com.LimeBits.RightHere.Extension"

    static func currentRegistrationState() -> FinderExtensionRegistrationState {
        let result = runPlugInKit(arguments: ["-m", "-i", extensionBundleIdentifier])
        if let state = registrationState(from: result) {
            return state
        }

        let finderSyncResult = runPlugInKit(arguments: ["-m", "-p", "com.apple.FinderSync"])
        if let state = registrationState(from: finderSyncResult) {
            return state
        }

        guard result.exitCode == 0 else {
            return .unavailable(unavailableMessage(for: result.output))
        }

        guard finderSyncResult.exitCode == 0 else {
            return .unavailable(unavailableMessage(for: finderSyncResult.output))
        }

        return .notRegistered
    }

    static func openExtensionSettings() {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

        if majorVersion < 13 {
            let paneURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Extensions.prefPane")
            if FileManager.default.fileExists(atPath: paneURL.path),
               NSWorkspace.shared.open(paneURL) {
                return
            }
        }

        let urlStrings = majorVersion >= 13
            ? [
                "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
                "x-apple.systempreferences:com.apple.ExtensionsPreferences"
            ]
            : [
                "x-apple.systempreferences:com.apple.preferences.extensions?Finder",
                "x-apple.systempreferences:com.apple.preferences.extensions"
            ]

        for urlString in urlStrings {
            if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                break
            }
        }
    }

    private static func registrationState(
        from result: (exitCode: Int32, output: String)
    ) -> FinderExtensionRegistrationState? {
        guard result.exitCode == 0 else { return nil }

        let lines = result.output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let line = lines.first(where: { $0.contains(extensionBundleIdentifier) }) else {
            return nil
        }

        if line.hasPrefix("+") {
            return .enabled(line)
        }

        if line.hasPrefix("-") || line.hasPrefix("!") {
            return .disabled(line)
        }

        return .unavailable(line)
    }

    private static func unavailableMessage(for output: String) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.localizedCaseInsensitiveContains("unauthorized discovery flag") {
            return "系统暂时不允许 RightHere 读取 Finder 扩展列表。这不代表扩展不可用；请在系统偏好设置的“扩展”中确认 RightHere。"
        }

        return trimmedOutput.isEmpty ? "系统暂时没有返回 Finder 扩展状态。" : trimmedOutput
    }

    private static func runPlugInKit(arguments: [String]) -> (exitCode: Int32, output: String) {
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
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return (1, error.localizedDescription)
        }
    }
}
