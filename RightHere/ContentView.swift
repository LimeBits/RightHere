import SwiftUI

struct ContentView: View {
    @State private var availableTemplates: [FileTemplate] = []
    @State private var enabledTemplates: Set<FileTemplate> = []
    @State private var hasRecentFinderResponse = false
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

                TemplateListScrollView {
                    VStack(spacing: 0) {
                        ForEach(availableTemplates) { template in
                            templateRow(template)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 28)
                }
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 260)
            }
            .padding(18)

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(hasRecentFinderResponse ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text("Finder 右键响应：\(hasRecentFinderResponse ? "最近可用" : "等待检测")")
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
            
            // Poll extension status periodically
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
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
    
    private func checkFinderResponseStatus() {
        hasRecentFinderResponse = false
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
