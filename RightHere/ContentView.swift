import SwiftUI

struct ContentView: View {
    @State private var availableTemplates: [FileTemplate] = []
    @State private var enabledTemplates: Set<FileTemplate> = []
    @State private var lastFinderCall: Date? = nil
    @State private var extensionRegistrationState: FinderExtensionRegistrationState = .checking
    @State private var now = Date()
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RightHere")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Finder 右键“新建文件”")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 14)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                finderExtensionStatusView

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
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 260)
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
                        .frame(maxWidth: .infinity, minHeight: 152, maxHeight: 230)
                    }
                }
            }
            .padding(18)

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isRecentFinderCall ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(finderCallStatusText)
                }

                Spacer()

                Text(appVersionText)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 34, alignment: .center)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.36))
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSettings()
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

    private var finderExtensionStatusView: some View {
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

            Button(action: openSystemExtensionSettings) {
                Label("扩展设置", systemImage: "gearshape")
            }
            .font(.system(size: 11))

            Button(action: refreshFinderExtensionRegistration) {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(extensionRegistrationState.backgroundColor)
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
        let available = SharedDefaults.getLocalAvailableFileTemplates()
        let enabled = SharedDefaults.getLocalEnabledFileTemplates()
        self.availableTemplates = available
        self.enabledTemplates = Set(enabled)
    }

    private func refreshExistingTemplatesOnFirstOpen() {
        SharedDefaults.refreshLocalTemplateCacheFromDiskIfNeeded()
        loadSettings()
    }
    
    private func saveSettings() {
        SharedDefaults.setLocalEnabledFileTemplates(Array(enabledTemplates))
    }
    
    private func openSystemExtensionSettings() {
        // macOS 13+: open Extensions preference pane directly
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
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

    private func refreshFinderExtensionRegistration() {
        extensionRegistrationState = .checking
        DispatchQueue.global(qos: .utility).async {
            let state = FinderExtensionInspector.currentRegistrationState()
            DispatchQueue.main.async {
                extensionRegistrationState = state
            }
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
            return "Finder 扩展状态：无法读取"
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
        case .disabled, .notRegistered, .unavailable:
            return true
        case .checking, .enabled:
            return false
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
            return "questionmark.circle.fill"
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
        case .notRegistered, .unavailable:
            return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .enabled:
            return Color.green.opacity(0.10)
        case .disabled:
            return Color.orange.opacity(0.10)
        case .notRegistered, .unavailable:
            return Color.red.opacity(0.10)
        case .checking:
            return Color.secondary.opacity(0.08)
        }
    }
}

enum FinderExtensionInspector {
    static let extensionBundleIdentifier = "com.b-vibe.RightHere.Extension"

    static func currentRegistrationState() -> FinderExtensionRegistrationState {
        let result = runPlugInKit(arguments: ["-m", "-A", "-i", extensionBundleIdentifier])

        guard result.exitCode == 0 else {
            return .unavailable(result.output.isEmpty ? "pluginkit 查询失败。" : result.output)
        }

        let lines = result.output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let line = lines.first(where: { $0.contains(extensionBundleIdentifier) }) else {
            return .notRegistered
        }

        if line.hasPrefix("+") {
            return .enabled(line)
        }

        if line.hasPrefix("-") || line.hasPrefix("!") {
            return .disabled(line)
        }

        return .unavailable(line)
    }

    static func openExtensionSettings() {
        let majorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let urlString = majorVersion >= 13
            ? "x-apple.systempreferences:com.apple.ExtensionsPreferences"
            : "x-apple.systempreferences:com.apple.preferences.extensions"

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
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
