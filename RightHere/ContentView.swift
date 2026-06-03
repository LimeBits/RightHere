import SwiftUI

struct ContentView: View {
    @State private var enabledTypes: Set<FileType> = Set(FileType.allCases)
    @State private var isExtensionActive = false
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RightHere")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text("Finder 右键“新建文件”扩展工具")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                Divider()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            // Content List
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 1. Extension Status Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("扩展启用状态")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isExtensionActive ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(isExtensionActive ? "已启用" : "未开启")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isExtensionActive ? .green : .orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isExtensionActive ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                            )
                        }
                        
                        Text("由于 macOS 安全限制，您需要手动在“系统设置”中开启 Finder 扩展插件，右键菜单才会生效。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                        
                        Text("macOS 15 已通过命令行自动启用扩展，无需手动操作。如需重新启用，请运行项目目录下的 deploy.sh。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                        
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 2. File Formats Card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("右键菜单显示的类型")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("勾选您希望在 Finder 右键新建菜单中出现的文件类型：")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        ForEach(FileType.allCases) { type in
                            Toggle(isOn: Binding(
                                get: { enabledTypes.contains(type) },
                                set: { isChecked in
                                    if isChecked {
                                        enabledTypes.insert(type)
                                    } else {
                                        enabledTypes.remove(type)
                                    }
                                    saveSettings()
                                }
                            )) {
                                HStack(spacing: 8) {
                                    Image(systemName: getIcon(for: type))
                                        .font(.system(size: 14))
                                        .foregroundColor(getIconColor(for: type))
                                        .frame(width: 20)
                                    Text(type.displayName)
                                        .font(.system(size: 13))
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    
                    // 3. Custom Templates Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("自定义模板")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("您可以打开应用专属模板目录，修改里面的文件内容（如设置 Word 默认字体、边距，或向 Markdown 写入初始格式），此后右键新建的文件将自动继承您的自定义模板。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                        
                        Button(action: openTemplatesDirectory) {
                            HStack {
                                Image(systemName: "folder")
                                Text("打开共享模板文件夹")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                    }
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                .padding(20)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSettings()
            checkExtensionStatus()
            
            // Poll extension status periodically
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                checkExtensionStatus()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func getIcon(for type: FileType) -> String {
        switch type {
        case .txt: return "doc.text"
        case .md: return "arrow.down.doc"
        case .docx: return "doc.richtext"
        case .xlsx: return "tablecells"
        case .pptx: return "play.rectangle"
        }
    }
    
    private func getIconColor(for type: FileType) -> Color {
        switch type {
        case .txt: return .secondary
        case .md: return Color(red: 0.18, green: 0.67, blue: 0.73)
        case .docx: return .blue
        case .xlsx: return .green
        case .pptx: return .orange
        }
    }
    
    private func loadSettings() {
        let saved = SharedDefaults.getEnabledFileTypes()
        self.enabledTypes = Set(saved)
    }
    
    private func saveSettings() {
        let array = Array(enabledTypes)
        SharedDefaults.setEnabledFileTypes(array)
    }
    
    private func openSystemExtensionSettings() {
        // macOS 13+: open Extensions preference pane directly
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openTemplatesDirectory() {
        if let url = SharedDefaults.templatesDirectoryURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func checkExtensionStatus() {
        if let lastActive = UserDefaults.standard.object(forKey: "extensionLastActive") as? Date {
            isExtensionActive = Date().timeIntervalSince(lastActive) < 30.0
        } else {
            isExtensionActive = false
        }
    }
}
