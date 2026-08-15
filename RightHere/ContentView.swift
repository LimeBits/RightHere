import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case templates
        case tools
        case advanced
        case updates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .templates: return L("Templates")
            case .tools: return L("Tools")
            case .advanced: return L("Advanced")
            case .updates: return L("Updates")
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
    @State private var isOpenInTerminalEnabled = true
    @State private var areShortcutLocationsEnabled = true
    @State private var areDevToolsEnabled = true
    @State private var areMenuIconsEnabled = true
    @State private var openHereAppSettings: [OpenHereAppSetting] = []
    @State private var shortcutLocations: [ShortcutLocation] = []
    @State private var draggedShortcutLocationID: UUID?
    @State private var shortcutDropTargetID: UUID?
    @State private var preferredLanguage: RightHereLanguage = .system
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
            // Picks up editors installed while the settings window was in the background.
            openHereAppSettings = SharedDefaults.getLocalOpenHereAppSettings()
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
            .frame(width: 230)
            .padding(.top, 20)
            // The segmented control caches its item titles, so it keeps the old
            // language until the view identity changes.
            .id(preferredLanguage)

            Group {
                switch selectedTab {
                case .templates:
                    templateSettingsTab
                case .tools:
                    toolsSettingsTab
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

    private var toolsSettingsTab: some View {
        // The three cards together are taller than the window, so this tab
        // scrolls as a whole. The Go To list deliberately has no scroller of its
        // own: a scroller inside a scroller forced this tab to absorb the full
        // list height, which pushed the tab picker off-screen.
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                terminalToolCard
                devToolsCard
                shortcutLocationsCard
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private var devToolsCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Dev Tools"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L("Copy full paths, file names, or Markdown links from the context menu. Multiple selections produce one result per line."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { areDevToolsEnabled },
                set: { isEnabled in
                    areDevToolsEnabled = isEnabled
                    SharedDefaults.setDevToolsEnabled(isEnabled)
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

    private var menuIconsCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Menu Icons"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L("Show icons next to items in the Finder context menu."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { areMenuIconsEnabled },
                set: { isEnabled in
                    areMenuIconsEnabled = isEnabled
                    SharedDefaults.setMenuIconsEnabled(isEnabled)
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

    private var terminalToolCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Open Here"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("Open a terminal or editor at that folder when you right-click a folder or its background. Only apps installed on this Mac appear."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { isOpenInTerminalEnabled },
                    set: { isEnabled in
                        isOpenInTerminalEnabled = isEnabled
                        SharedDefaults.setOpenInTerminalEnabled(isEnabled)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            if isOpenInTerminalEnabled {
                Divider().opacity(0.7)

                if installedOpenHereApps.isEmpty {
                    Text(L("No supported terminal or editor detected."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                } else {
                    // Two columns: the names are short, so a single column left a
                    // lot of empty width and made the rows feel cramped.
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), alignment: .leading),
                            GridItem(.flexible(), alignment: .leading)
                        ],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(installedOpenHereApps) { setting in
                            openHereAppRow(setting)
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
        .cornerRadius(6)
    }

    private func openHereAppRow(_ setting: OpenHereAppSetting) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { setting.isEnabled },
                set: { isEnabled in
                    setOpenHereApp(setting.app, isEnabled: isEnabled)
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            Text(setting.app.displayName)
                .font(.system(size: 12))

            Spacer(minLength: 0)
        }
    }

    /// Only apps present on this machine are worth showing a switch for.
    private var installedOpenHereApps: [OpenHereAppSetting] {
        openHereAppSettings.filter { $0.app.isInstalled }
    }

    private func setOpenHereApp(_ app: OpenHereApp, isEnabled: Bool) {
        openHereAppSettings = openHereAppSettings.map { setting in
            setting.app == app ? OpenHereAppSetting(app: app, isEnabled: isEnabled) : setting
        }
        SharedDefaults.setOpenHereAppSettings(openHereAppSettings)
    }

    private var shortcutLocationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bookmark")
                    .foregroundColor(.secondary)
                    .frame(width: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Go To"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("Add frequently used files, folders, or hidden paths to reach them from the Finder context menu."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(L("Drag items to set their Finder menu order."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { areShortcutLocationsEnabled },
                    set: { isEnabled in
                        areShortcutLocationsEnabled = isEnabled
                        SharedDefaults.setShortcutLocationsEnabled(isEnabled)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            Divider().opacity(0.7)

            if shortcutLocations.isEmpty {
                emptyShortcutLocationsView
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
            } else {
                // No inner scroll view: the whole tab scrolls instead. Nesting a
                // scroller here forced the outer layout to reserve a fixed slab of
                // height, which is what pushed the tab picker off-screen.
                VStack(spacing: 0) {
                    ForEach(shortcutLocations) { location in
                        shortcutLocationRow(location)
                            .onDrop(
                                of: [.text],
                                delegate: ShortcutLocationDropDelegate(
                                    destination: location,
                                    locations: $shortcutLocations,
                                    draggedLocationID: $draggedShortcutLocationID,
                                    dropTargetID: $shortcutDropTargetID,
                                    save: saveShortcutLocations
                                )
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.7)

            HStack(spacing: 8) {
                Button(action: addShortcutItem) {
                    Label(L("Add File or Folder"), systemImage: "folder.badge.plus")
                }

                Button(action: addShortcutPathManually) {
                    // Not text.cursor: it renders as a CJK glyph under a Chinese
                    // UI. This one reads as "a path" in any language.
                    Label(L("Enter Path"), systemImage: "arrow.turn.down.right")
                }

                Spacer(minLength: 0)
            }
            .font(.system(size: 11))
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.24))
        .cornerRadius(6)
    }

    private var templateSettingsTab: some View {
        // Scrolls as a whole, like the tools tab: a long template list would
        // otherwise grow this tab past the window and squeeze the tab picker out.
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Custom Templates"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(L("Select the templates to show in the Finder context menu. Add templates using names like template.rtf."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Button(action: openTemplatesDirectory) {
                        Label(L("Open Templates Folder"), systemImage: "folder")
                    }
                    .font(.system(size: 12))

                    Button(action: refreshTemplates) {
                        Label(L("Refresh"), systemImage: "arrow.clockwise")
                    }
                    .font(.system(size: 12))
                }

                Divider()

                if availableTemplates.isEmpty {
                    emptyTemplatesView
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 10) {
                        if enabledTemplates.isEmpty {
                            disabledTemplatesWarning
                        }

                        // No inner scroll view: the whole tab scrolls instead, so this
                        // list just grows with its content.
                        VStack(spacing: 0) {
                            ForEach(availableTemplates) { template in
                                templateRow(template)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.24))
            .cornerRadius(6)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private var updateSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            updateSettingsView

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(.blue)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Check Manually"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("Check GitHub Releases for the latest stable version now."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: checkForUpdates) {
                    Label(L("Check for Updates"), systemImage: "magnifyingglass")
                }
                .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 6) {
                Text(L("Current Version"))
                    .font(.system(size: 12, weight: .semibold))
                Text(appVersionText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
        // Six cards no longer fit the window height, so this tab scrolls as a
        // whole (same reasoning as the Tools tab).
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                languageCard
                finderExtensionStatusView
                extensionControlView
                menuIconsCard

                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("System Extension Settings"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(L("Useful for checking whether the Finder extension is enabled. Some macOS versions only open the main System Settings page."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button(action: openSystemExtensionSettings) {
                        Label(L("Open Extension Settings"), systemImage: "gearshape")
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
                        Text(L("Diagnostics"))
                            .font(.system(size: 12, weight: .semibold))
                        Text(L("Copy the version, templates folder, and recent Finder call status for troubleshooting."))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button(action: copyDiagnostics) {
                        Label(L("Copy Diagnostics"), systemImage: "doc.on.doc")
                    }
                    .font(.system(size: 11))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.32))
                .cornerRadius(6)
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
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

    private func shortcutLocationRow(_ location: ShortcutLocation) -> some View {
        let isDragged = draggedShortcutLocationID == location.id
        let isDropTarget = shortcutDropTargetID == location.id && !isDragged

        return HStack(spacing: 0) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
                .help(L("Drag to reorder"))
                .accessibilityLabel(L("Drag to reorder"))
                .onDrag {
                    draggedShortcutLocationID = location.id
                    shortcutDropTargetID = nil
                    return NSItemProvider(object: location.id.uuidString as NSString)
                }

            Toggle("", isOn: Binding(
                get: { location.isEnabled },
                set: { isChecked in
                    updateShortcutLocation(location.id) { item in
                        item.isEnabled = isChecked
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .frame(width: 24, alignment: .leading)
            .padding(.leading, 8)

            Image(systemName: shortcutIcon(for: location))
                .font(.system(size: 14))
                .foregroundColor(location.exists ? .blue : .secondary)
                .frame(width: 20, height: 22)
                .padding(.leading, 6)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(location.resolvedDisplayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(location.path)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !location.exists {
                Text(L("Unverified"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                    .cornerRadius(4)
                    .padding(.trailing, 8)
            }

            HStack(spacing: 4) {
                Button(action: { renameShortcutLocation(location) }) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 26, height: 24)
                }
                .buttonStyle(.plain)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .cornerRadius(6)
                .help(L("Rename"))

                Button(action: { openShortcutLocation(location) }) {
                    Image(systemName: "arrow.up.forward")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("Open"))

                Button(action: { revealShortcutLocation(location) }) {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("Show in Finder"))
                .disabled(!location.exists)

                Button(action: { deleteShortcutLocation(location) }) {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("Delete"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 4)
        .background(isDropTarget ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(
            Group {
                if isDropTarget {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                }
            },
            alignment: .top
        )
        .opacity(isDragged ? 0.45 : 1)
        .scaleEffect(isDragged ? 0.98 : 1)
        .animation(.easeInOut(duration: 0.16), value: isDragged)
        .animation(.easeInOut(duration: 0.16), value: isDropTarget)
    }

    private var emptyTemplatesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text(L("No templates found"))
                .font(.system(size: 13, weight: .semibold))

            Text(L("Open the templates folder and add template.txt, template.md, or template.rtf."))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyShortcutLocationsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 24))
                .foregroundColor(.secondary)

            Text(L("No Go To items yet"))
                .font(.system(size: 13, weight: .semibold))

            Text(L("Add files, folders, or hidden paths to reach them from the Finder context menu."))
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

            Text(L("No templates are enabled, so New File will not appear in the Finder context menu."))
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
                Label(L("Refresh"), systemImage: "arrow.clockwise")
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(extensionRegistrationState.backgroundColor)
        .cornerRadius(6)
    }

    private var isAutomaticUpdateToggleLocked: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private var automaticUpdateDescription: String {
        #if DEBUG
        return L("Debug builds have no Sparkle public key, so automatic checks are disabled to avoid false update failures. Manual checks still work.")
        #else
        return L("Check for new versions automatically. You can still check manually from the menu bar.")
        #endif
    }

    private var updateSettingsView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Automatic Updates"))
                    .font(.system(size: 12, weight: .semibold))
                Text(automaticUpdateDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: Binding(
                get: { automaticallyChecksForUpdates },
                set: { isEnabled in
                    RightHereUpdater.shared.automaticallyChecksForUpdates = isEnabled
                    // Debug builds refuse the change, so mirror the real state back.
                    automaticallyChecksForUpdates = RightHereUpdater.shared.automaticallyChecksForUpdates
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(isAutomaticUpdateToggleLocked)
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
                Text(L("Context Menu"))
                    .font(.system(size: 12, weight: .semibold))
                Text(isFinderMenuDisabled ? L("RightHere is temporarily hidden from the Finder context menu.") : L("Turning this off removes New File from the Finder context menu."))
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

    private var languageCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "globe")
                .foregroundColor(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Language"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L("Applies to the settings window and the Finder context menu, including the names of newly created files."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Picker("", selection: Binding(
                get: { preferredLanguage },
                set: { language in
                    preferredLanguage = language
                    SharedDefaults.setPreferredLanguage(language)
                    // The status-bar menu is built once at launch, so it keeps the
                    // old language until it is rebuilt.
                    NotificationCenter.default.post(
                        name: SharedDefaults.preferredLanguageDidChangeNotificationName,
                        object: nil
                    )
                }
            )) {
                ForEach(RightHereLanguage.allCases) { language in
                    // Passing the current selection makes the dependency visible
                    // to SwiftUI, so "Follow System" re-renders on switch.
                    Text(language.displayName(in: preferredLanguage)).tag(language)
                }
            }
            .labelsHidden()
            .frame(width: 130)
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

    private func shortcutIcon(for location: ShortcutLocation) -> String {
        switch location.kind {
        case .directory:
            return "folder"
        case .file:
            return "doc"
        case .unknown:
            return "questionmark.square"
        }
    }
    
    private func loadSettings() {
        let available = SharedDefaults.getAvailableFileTemplates()
        let enabled = SharedDefaults.getEnabledFileTemplates()
        self.availableTemplates = available
        self.enabledTemplates = Set(enabled)
        self.isFinderMenuDisabled = SharedDefaults.isFinderMenuDisabled()
        self.isOpenInTerminalEnabled = SharedDefaults.isOpenInTerminalEnabled()
        self.areShortcutLocationsEnabled = SharedDefaults.areShortcutLocationsEnabled()
        self.areDevToolsEnabled = SharedDefaults.areDevToolsEnabled()
        self.areMenuIconsEnabled = SharedDefaults.areMenuIconsEnabled()
        self.openHereAppSettings = SharedDefaults.getLocalOpenHereAppSettings()
        self.shortcutLocations = SharedDefaults.getLocalShortcutLocations()
        self.preferredLanguage = SharedDefaults.getPreferredLanguage()
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
        Language: \(SharedDefaults.getPreferredLanguage().diagnosticDescription)
        Finder call: \(finderCallStatusText)
        Finder extension: \(extensionRegistrationState.title)
        Templates directory: \(SharedDefaults.templatesDirectoryURL?.path ?? "unavailable")
        Enabled templates: \(enabled.isEmpty ? "none" : enabled)
        Open here: \(SharedDefaults.isOpenInTerminalEnabled() ? "enabled" : "disabled") (\(openHereDiagnosticsText))
        Shortcut locations: \(SharedDefaults.areShortcutLocationsEnabled() ? "enabled" : "disabled") (\(SharedDefaults.getShortcutLocations().filter(\.isEnabled).count) enabled)
        Dev tools: \(SharedDefaults.areDevToolsEnabled() ? "enabled" : "disabled")
        Finder menu: \(SharedDefaults.isFinderMenuDisabled() ? "disabled" : "enabled")
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)

        let alert = NSAlert()
        alert.messageText = L("Diagnostics Copied")
        alert.informativeText = L("Diagnostics do not include template contents or your file contents.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("OK"))
        alert.runModal()
    }

    private var openHereDiagnosticsText: String {
        let states = SharedDefaults.getOpenHereAppSettings().map { setting -> String in
            let installed = setting.app.isInstalled ? "installed" : "missing"
            return "\(setting.app.rawValue):\(setting.isEnabled ? "on" : "off")/\(installed)"
        }
        return states.joined(separator: ", ")
    }

    private func refreshExistingTemplatesOnFirstOpen() {
        SharedDefaults.refreshTemplateCacheFromDisk()
        loadSettings()
    }
    
    private func saveSettings() {
        SharedDefaults.setEnabledFileTemplates(Array(enabledTemplates))
    }

    private func saveShortcutLocations() {
        shortcutLocations = shortcutLocations
            .enumerated()
            .map { index, location in
                var updated = location
                updated.sortOrder = index
                return updated.normalized()
            }
            .sorted()
        SharedDefaults.setShortcutLocations(shortcutLocations)
    }

    private func updateShortcutLocation(_ id: UUID, update: (inout ShortcutLocation) -> Void) {
        guard let index = shortcutLocations.firstIndex(where: { $0.id == id }) else { return }
        update(&shortcutLocations[index])
        saveShortcutLocations()
    }

    private func appendShortcutLocation(path: String, displayName: String? = nil) {
        let expandedPath = ShortcutLocation.expandPath(path)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        let kind: ShortcutLocation.Kind = exists ? (isDirectory.boolValue ? .directory : .file) : .unknown
        let inferredName = URL(fileURLWithPath: expandedPath).lastPathComponent
        let location = ShortcutLocation(
            displayName: displayName ?? (inferredName.isEmpty ? expandedPath : inferredName),
            path: path,
            kind: kind,
            isEnabled: true,
            sortOrder: shortcutLocations.count
        )

        shortcutLocations.append(location.normalized())
        saveShortcutLocations()
    }

    private func addShortcutItem() {
        let panel = NSOpenPanel()
        panel.title = L("Add File or Folder")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = true

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            appendShortcutLocation(path: url.path)
        }
    }

    private func addShortcutPathManually() {
        promptForText(
            title: L("Enter Go To Path"),
            message: L("Hidden paths and ~ are supported, for example ~/.zshrc, /etc/hosts, or ~/.codex."),
            placeholder: "~/.zshrc"
        ) { path in
            appendShortcutLocation(path: path)
        }
    }

    private func renameShortcutLocation(_ location: ShortcutLocation) {
        promptForText(
            title: L("Rename Go To Item"),
            message: location.path,
            placeholder: location.resolvedDisplayName,
            initialValue: location.resolvedDisplayName
        ) { name in
            updateShortcutLocation(location.id) { item in
                item.displayName = name
                // A renamed default is now the user's own name, so it must stop
                // following the language setting.
                item.localizationKey = nil
            }
        }
    }

    private func deleteShortcutLocation(_ location: ShortcutLocation) {
        shortcutLocations.removeAll { $0.id == location.id }
        saveShortcutLocations()
    }

    private func openShortcutLocation(_ location: ShortcutLocation) {
        NSWorkspace.shared.open(location.url)
    }

    private func revealShortcutLocation(_ location: ShortcutLocation) {
        guard location.exists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([location.url])
    }

    private func promptForText(
        title: String,
        message: String,
        placeholder: String,
        initialValue: String = "",
        completion: (String) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("OK"))
        alert.addButton(withTitle: L("Cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        textField.placeholderString = placeholder
        textField.stringValue = initialValue
        alert.accessoryView = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let value = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        completion(value)
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
            return L("Last Finder call: not detected yet")
        }

        let elapsed = max(0, Int(now.timeIntervalSince(lastFinderCall)))

        if elapsed < 10 {
            return L("Last Finder call: just now")
        }

        if elapsed < 60 {
            return L("Last Finder call: %lld seconds ago", elapsed)
        }

        let minutes = elapsed / 60
        if minutes < 60 {
            return L("Last Finder call: %lld minutes ago", minutes)
        }

        let hours = minutes / 60
        return L("Last Finder call: %lld hours ago", hours)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("Unknown Version")
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let build, !build.isEmpty {
            return "RightHere \(version) (\(build))"
        }

        return "RightHere \(version)"
    }
}

private struct ShortcutLocationDropDelegate: DropDelegate {
    let destination: ShortcutLocation
    @Binding var locations: [ShortcutLocation]
    @Binding var draggedLocationID: UUID?
    @Binding var dropTargetID: UUID?
    let save: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedLocationID, draggedLocationID != destination.id else {
            return
        }

        guard dropTargetID != destination.id else {
            return
        }
        dropTargetID = destination.id

        guard
            let sourceIndex = locations.firstIndex(where: { $0.id == draggedLocationID }),
            let destinationIndex = locations.firstIndex(where: { $0.id == destination.id })
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            let item = locations.remove(at: sourceIndex)
            let insertionIndex = sourceIndex < destinationIndex ? destinationIndex : destinationIndex
            locations.insert(item, at: min(insertionIndex, locations.count))
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedLocationID != nil else { return false }
        save()
        draggedLocationID = nil
        dropTargetID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // Keep the target marker while moving between rows to avoid flicker.
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedLocationID != nil
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
            return L("Finder extension: checking")
        case .enabled:
            return L("Finder extension: enabled")
        case .disabled:
            return L("Finder extension: not enabled")
        case .notRegistered:
            return L("Finder extension: not found by the system")
        case .unavailable:
            return L("Finder extension: status unavailable")
        }
    }

    var message: String {
        switch self {
        case .checking:
            return L("Reading the system extension registration state.")
        case .enabled:
            return L("If the context menu still does not appear, open your home folder in Finder and right-click the background.")
        case .disabled:
            return L("Enable the RightHere Finder extension in System Settings.")
        case .notRegistered:
            return L("This build may not be signed correctly, or the system has not registered the embedded extension yet.")
        case .unavailable(let detail):
            return detail
        }
    }

    var launchAlertMessage: String {
        switch self {
        case .disabled:
            return L("RightHere is installed, but its Finder extension is not enabled yet. Enable RightHere in System Settings, then restart Finder.")
        case .notRegistered:
            return L("RightHere is installed, but the system did not find its Finder extension. This usually means an unsigned or signature-skipped test build was installed. Use a signed installer, or rebuild with your own Apple Developer account.")
        case .unavailable(let detail):
            return L("RightHere cannot read the Finder extension status right now.\n\n%@", detail)
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
            return L("Extension Settings")
        case .checking, .enabled, .unavailable:
            return L("Open Extensions")
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
            return L("The system is not allowing RightHere to read the Finder extension list right now. This does not mean the extension is unavailable; confirm RightHere under Extensions in System Settings.")
        }

        return trimmedOutput.isEmpty ? L("The system did not return a Finder extension status.") : trimmedOutput
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
