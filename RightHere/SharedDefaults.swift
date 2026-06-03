import Foundation

public struct SharedDefaults {
    public static let groupIdentifier = "group.com.b-vibe.RightHere"
    
    public static var sharedSuite: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
    
    // Key for enabled file types: Array of file extension strings (e.g. ["txt", "md", "docx", "xlsx", "pptx"])
    public static let enabledTypesKey = "enabledFileTypes"
    
    public static var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }
    
    public static var templatesDirectoryURL: URL? {
        guard let containerURL = sharedContainerURL else { return nil }
        let url = containerURL.appendingPathComponent("Templates", isDirectory: true)
        return url
    }
    
    public static func getEnabledFileTypes() -> [FileType] {
        guard let defaults = sharedSuite,
              let saved = defaults.stringArray(forKey: enabledTypesKey) else {
            // Default active types
            return FileType.allCases
        }
        return saved.compactMap { FileType(rawValue: $0) }
    }
    
    public static func setEnabledFileTypes(_ types: [FileType]) {
        let rawValues = types.map { $0.rawValue }
        sharedSuite?.set(rawValues, forKey: enabledTypesKey)
        sharedSuite?.synchronize()
        
        // Notify Finder Sync extension of the update
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.b-vibe.RightHere.SettingsChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}

public enum FileType: String, CaseIterable, Identifiable {
    case txt
    case md
    case docx
    case xlsx
    case pptx
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        switch self {
        case .txt: return "文本文件 (.txt)"
        case .md: return "Markdown (.md)"
        case .docx: return "Word 文档 (.docx)"
        case .xlsx: return "Excel 工作表 (.xlsx)"
        case .pptx: return "PowerPoint 演示文稿 (.pptx)"
        }
    }
    
    public var defaultFileName: String {
        switch self {
        case .txt: return "新建文本文档"
        case .md: return "新建 Markdown 文档"
        case .docx: return "新建 Word 文档"
        case .xlsx: return "新建 Excel 工作表"
        case .pptx: return "新建 PowerPoint 演示文稿"
        }
    }
    
    public var fileExtension: String {
        return self.rawValue
    }
}
