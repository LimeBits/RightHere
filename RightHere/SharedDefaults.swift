import Foundation

public struct SharedDefaults {
    public static let groupIdentifier = "group.com.b-vibe.RightHere"
    
    public static var sharedSuite: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
    
    // Key for enabled file types: Array of file extension strings (e.g. ["txt", "md", "docx", "xlsx", "pptx"])
    public static let enabledTypesKey = "enabledFileTypes"
    public static let disabledTypesKey = "disabledFileTypes"
    public static let extensionLastActiveKey = "extensionLastActive"
    public static let templateCacheKey = "templateCache"
    public static let localTemplateCacheKey = "localTemplateCache"
    public static let localDisabledTypesKey = "localDisabledFileTypes"
    
    public static var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
    }
    
    public static var templatesDirectoryURL: URL? {
        guard let containerURL = sharedContainerURL else { return nil }
        let url = containerURL.appendingPathComponent("Templates", isDirectory: true)
        return url
    }
    
    public static func getAvailableFileTemplates() -> [FileTemplate] {
        let cachedTemplates = getCachedTemplateRecords().map { $0.template }
        if !cachedTemplates.isEmpty {
            return cachedTemplates.sorted()
        }

        return defaultFileTemplates
    }

    public static func getLocalAvailableFileTemplates() -> [FileTemplate] {
        let cachedTemplates = getLocalTemplateRecords().map { $0.template }
        if !cachedTemplates.isEmpty {
            return cachedTemplates.sorted()
        }

        return defaultFileTemplates
    }

    public static func getLocalEnabledFileTemplates() -> [FileTemplate] {
        let availableTemplates = getLocalAvailableFileTemplates()
        let disabled = Set(UserDefaults.standard.stringArray(forKey: localDisabledTypesKey) ?? [])
        return availableTemplates.filter { !disabled.contains($0.fileExtension) }
    }

    public static func setLocalEnabledFileTemplates(_ templates: [FileTemplate]) {
        let enabledExtensions = Set(templates.map { $0.fileExtension })
        let disabledExtensions = getLocalAvailableFileTemplates()
            .map { $0.fileExtension }
            .filter { !enabledExtensions.contains($0) }

        UserDefaults.standard.set(disabledExtensions, forKey: localDisabledTypesKey)
        notifyLocalSettingsChanged(enabledExtensions: enabledExtensions)
    }

    public static func getLocalTemplateRecord(for template: FileTemplate) -> TemplateRecord? {
        let records = getLocalTemplateRecords()
        return records.first { $0.template == template }
            ?? defaultTemplateRecords.first { $0.template == template }
    }

    public static func getTemplateRecord(for template: FileTemplate) -> TemplateRecord? {
        let records = getCachedTemplateRecords()
        return records.first { $0.template == template }
            ?? defaultTemplateRecords.first { $0.template == template }
    }

    public static func refreshTemplateCacheFromDisk() {
        TemplateAssets.initializeDefaultTemplates()

        let records = readTemplateRecordsFromDisk()
        saveTemplateRecords(records)
        saveLocalTemplateRecords(records)
        notifyLocalSettingsChanged()
    }

    public static func refreshLocalTemplateCacheFromDiskIfNeeded() {
        let records = readTemplateRecordsFromDisk()
        let sortedRecords = records.sorted { $0.template < $1.template }
        guard sortedRecords != getLocalTemplateRecords() else { return }

        saveLocalTemplateRecords(sortedRecords)
        notifyLocalSettingsChanged()
    }

    public static func getEnabledFileTemplates() -> [FileTemplate] {
        let availableTemplates = getAvailableFileTemplates()
        let disabledExtensions = getDisabledFileExtensions(availableTemplates: availableTemplates)
        return availableTemplates.filter { !disabledExtensions.contains($0.fileExtension) }
    }

    public static func setEnabledFileTemplates(_ templates: [FileTemplate]) {
        let enabledExtensions = Set(templates.map { $0.fileExtension })
        let disabledExtensions = getAvailableFileTemplates()
            .map { $0.fileExtension }
            .filter { !enabledExtensions.contains($0) }

        sharedSuite?.set(disabledExtensions, forKey: disabledTypesKey)
        sharedSuite?.removeObject(forKey: enabledTypesKey)
        sharedSuite?.synchronize()

        notifySettingsChanged()
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
        sharedSuite?.removeObject(forKey: disabledTypesKey)
        sharedSuite?.synchronize()

        notifySettingsChanged()
    }

    public static func markExtensionActive() {
        UserDefaults.standard.set(Date(), forKey: extensionLastActiveKey)
    }

    public static func getExtensionLastActive() -> Date? {
        UserDefaults.standard.object(forKey: extensionLastActiveKey) as? Date
    }

    private static func getDisabledFileExtensions(availableTemplates: [FileTemplate]) -> Set<String> {
        guard let defaults = sharedSuite else { return [] }

        if let disabled = defaults.stringArray(forKey: disabledTypesKey) {
            return Set(disabled.map { $0.lowercased() })
        }

        guard let legacyEnabled = defaults.stringArray(forKey: enabledTypesKey) else {
            return []
        }

        let enabledBuiltIns = Set(legacyEnabled.map { $0.lowercased() })
        let builtInExtensions = Set(FileType.allCases.map { $0.fileExtension })
        return Set(availableTemplates.map { $0.fileExtension }.filter { extensionName in
            builtInExtensions.contains(extensionName) && !enabledBuiltIns.contains(extensionName)
        })
    }

    private static func notifySettingsChanged() {
        // Notify Finder Sync extension of the update
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.b-vibe.RightHere.SettingsChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static func notifyLocalSettingsChanged(enabledExtensions: Set<String>? = nil) {
        let enabled = enabledExtensions ?? Set(getLocalEnabledFileTemplates().map { $0.fileExtension })
        var userInfo: [String: Any] = ["enabledExtensions": Array(enabled)]

        if let data = UserDefaults.standard.data(forKey: localTemplateCacheKey) {
            userInfo["templateRecords"] = data
        }

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.b-vibe.RightHere.SettingsChanged"),
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    private static func getCachedTemplateRecords() -> [TemplateRecord] {
        guard let data = sharedSuite?.data(forKey: templateCacheKey),
              let records = try? JSONDecoder().decode([TemplateRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.template < $1.template }
    }

    private static func saveTemplateRecords(_ records: [TemplateRecord]) {
        guard let data = try? JSONEncoder().encode(records.sorted { $0.template < $1.template }) else {
            return
        }

        sharedSuite?.set(data, forKey: templateCacheKey)
        sharedSuite?.synchronize()
    }

    private static func getLocalTemplateRecords() -> [TemplateRecord] {
        guard let data = UserDefaults.standard.data(forKey: localTemplateCacheKey),
              let records = try? JSONDecoder().decode([TemplateRecord].self, from: data) else {
            return []
        }

        return records.sorted { $0.template < $1.template }
    }

    private static func saveLocalTemplateRecords(_ records: [TemplateRecord]) {
        guard let data = try? JSONEncoder().encode(records.sorted { $0.template < $1.template }) else {
            return
        }

        UserDefaults.standard.set(data, forKey: localTemplateCacheKey)
    }

    private static func readTemplateRecordsFromDisk() -> [TemplateRecord] {
        var recordsByExtension = Dictionary(
            uniqueKeysWithValues: defaultTemplateRecords.map { ($0.template.fileExtension, $0) }
        )

        guard let templatesDir = templatesDirectoryURL else {
            return Array(recordsByExtension.values).sorted { $0.template < $1.template }
        }

        let fileManager = FileManager.default
        guard let templateFiles = try? fileManager.contentsOfDirectory(
            at: templatesDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return Array(recordsByExtension.values).sorted { $0.template < $1.template }
        }

        for fileURL in templateFiles {
            let fileName = fileURL.lastPathComponent
            guard fileName.hasPrefix("template.") else { continue }

            let fileExtension = String(fileName.dropFirst("template.".count)).lowercased()
            guard !fileExtension.isEmpty else { continue }
            guard let data = try? Data(contentsOf: fileURL) else { continue }

            let template = FileTemplate(fileExtension: fileExtension)
            recordsByExtension[fileExtension] = TemplateRecord(template: template, data: data)
        }

        return Array(recordsByExtension.values).sorted { $0.template < $1.template }
    }

    public static var defaultFileTemplates: [FileTemplate] {
        defaultTemplateRecords.map { $0.template }.sorted()
    }

    private static var defaultTemplateRecords: [TemplateRecord] {
        [
            TemplateRecord(template: FileTemplate(fileExtension: "txt"), data: Data()),
            TemplateRecord(template: FileTemplate(fileExtension: "md"), data: Data()),
            TemplateRecord(template: FileTemplate(fileExtension: "docx"), data: Data(base64Encoded: TemplateAssets.docxBase64) ?? Data()),
            TemplateRecord(template: FileTemplate(fileExtension: "xlsx"), data: Data(base64Encoded: TemplateAssets.xlsxBase64) ?? Data()),
            TemplateRecord(template: FileTemplate(fileExtension: "pptx"), data: Data(base64Encoded: TemplateAssets.pptxBase64) ?? Data())
        ]
    }
}

public struct TemplateRecord: Codable, Hashable {
    public let template: FileTemplate
    public let data: Data
}

public struct FileTemplate: Identifiable, Hashable, Comparable, Codable {
    public let fileExtension: String

    public var id: String { fileExtension }

    public init(fileExtension: String) {
        self.fileExtension = fileExtension.lowercased()
    }

    private enum CodingKeys: String, CodingKey {
        case fileExtension
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.fileExtension = try container.decode(String.self, forKey: .fileExtension).lowercased()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileExtension, forKey: .fileExtension)
    }

    public var displayName: String {
        switch fileExtension {
        case "txt": return "文本文件 (.txt)"
        case "md": return "Markdown (.md)"
        case "docx": return "Word 文档 (.docx)"
        case "xlsx": return "Excel 工作表 (.xlsx)"
        case "pptx": return "PowerPoint 演示文稿 (.pptx)"
        case "rtf": return "富文本文件 (.rtf)"
        default: return "\(fileExtension.uppercased()) 文件 (.\(fileExtension))"
        }
    }

    public var defaultFileName: String {
        switch fileExtension {
        case "txt": return "新建文本文档"
        case "md": return "新建 Markdown 文档"
        case "docx": return "新建 Word 文档"
        case "xlsx": return "新建 Excel 工作表"
        case "pptx": return "新建 PowerPoint 演示文稿"
        case "rtf": return "新建富文本文件"
        default: return "新建 \(fileExtension.uppercased()) 文件"
        }
    }

    public var templateFileName: String {
        "template.\(fileExtension)"
    }

    public static func < (lhs: FileTemplate, rhs: FileTemplate) -> Bool {
        let order = ["txt", "md", "rtf", "docx", "xlsx", "pptx"]
        let leftIndex = order.firstIndex(of: lhs.fileExtension)
        let rightIndex = order.firstIndex(of: rhs.fileExtension)

        switch (leftIndex, rightIndex) {
        case let (left?, right?):
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.fileExtension < rhs.fileExtension
        }
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
