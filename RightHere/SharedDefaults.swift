import Foundation

public struct SharedDefaults {
    public static let groupIdentifier = "group.com.LimeBits.RightHere"
    
    public static var sharedSuite: UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
    
    // Key for enabled file types: Array of file extension strings (e.g. ["txt", "md", "docx", "xlsx", "pptx"])
    public static let enabledTypesKey = "enabledFileTypes"
    public static let disabledTypesKey = "disabledFileTypes"
    public static let extensionLastActiveKey = "extensionLastActive"
    public static let extensionDidBecomeActiveNotificationName = Notification.Name("com.LimeBits.RightHere.ExtensionDidBecomeActive")
    public static let extensionDiagnosticNotificationName = Notification.Name("com.LimeBits.RightHere.ExtensionDiagnostic")
    public static let extensionDiagnosticSnapshotRequestName = Notification.Name("com.LimeBits.RightHere.ExtensionDiagnosticSnapshotRequest")
    public static let extensionDiagnosticSnapshotNotificationName = Notification.Name("com.LimeBits.RightHere.ExtensionDiagnosticSnapshot")
    public static let templateCacheKey = "templateCache"
    public static let localTemplateCacheKey = "localTemplateCache"
    public static let localDisabledTypesKey = "localDisabledFileTypes"
    public static let finderMenuDisabledKey = "finderMenuDisabled"
    private static let extensionDiagnosticBufferKey = "extensionDiagnosticBuffer"
    private static let extensionDiagnosticRecordUserInfoKey = "record"
    private static let extensionDiagnosticRecordsUserInfoKey = "records"
    private static let maximumDiagnosticRecordCount = 100
    private static let diagnosticLock = NSLock()
    
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
        let disabled: Set<String>
        if sharedSuite != nil {
            disabled = getDisabledFileExtensions(availableTemplates: availableTemplates)
        } else {
            disabled = Set(UserDefaults.standard.stringArray(forKey: localDisabledTypesKey) ?? [])
        }
        return availableTemplates.filter { !disabled.contains($0.fileExtension) }
    }

    public static func setLocalEnabledFileTemplates(_ templates: [FileTemplate]) {
        let enabledExtensions = Set(templates.map { $0.fileExtension })
        let disabledExtensions = getLocalAvailableFileTemplates()
            .map { $0.fileExtension }
            .filter { !enabledExtensions.contains($0) }

        UserDefaults.standard.set(disabledExtensions, forKey: localDisabledTypesKey)
        setEnabledFileTemplates(templates)
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
        notifySettingsChanged()
        notifyLocalSettingsChanged()
    }

    public static func refreshTemplateCacheFromDiskIfNeeded() {
        let records = readTemplateRecordsFromDisk().sorted { $0.template < $1.template }
        let sharedChanged = records != getCachedTemplateRecords()
        let localChanged = records != getLocalTemplateRecords()
        guard sharedChanged || localChanged else { return }

        saveTemplateRecords(records)
        saveLocalTemplateRecords(records)
        notifySettingsChanged()
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

    public static func isFinderMenuDisabled() -> Bool {
        if let sharedSuite {
            return sharedSuite.bool(forKey: finderMenuDisabledKey)
        }

        return UserDefaults.standard.bool(forKey: finderMenuDisabledKey)
    }

    public static func setFinderMenuDisabled(_ isDisabled: Bool) {
        sharedSuite?.set(isDisabled, forKey: finderMenuDisabledKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(isDisabled, forKey: finderMenuDisabledKey)
        notifySettingsChanged()
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
        DistributedNotificationCenter.default().postNotificationName(
            extensionDidBecomeActiveNotificationName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func recordExtensionActiveLocally() {
        UserDefaults.standard.set(Date(), forKey: extensionLastActiveKey)
    }

    public static func getExtensionLastActive() -> Date? {
        UserDefaults.standard.object(forKey: extensionLastActiveKey) as? Date
    }

    public static func recordExtensionDiagnostic(_ message: String) {
        let record = ExtensionDiagnosticRecord(timestamp: Date(), message: message)

        diagnosticLock.lock()
        var records = loadDiagnosticRecords()
        records.append(record)
        records = Array(records.suffix(maximumDiagnosticRecordCount))
        saveDiagnosticRecords(records)
        diagnosticLock.unlock()

        guard let data = try? JSONEncoder().encode(record) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            extensionDiagnosticNotificationName,
            object: nil,
            userInfo: [extensionDiagnosticRecordUserInfoKey: data],
            deliverImmediately: true
        )
    }

    public static func requestExtensionDiagnosticSnapshot() {
        DistributedNotificationCenter.default().postNotificationName(
            extensionDiagnosticSnapshotRequestName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func publishExtensionDiagnosticSnapshot() {
        diagnosticLock.lock()
        let records = loadDiagnosticRecords()
        diagnosticLock.unlock()

        guard let data = try? JSONEncoder().encode(records) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            extensionDiagnosticSnapshotNotificationName,
            object: nil,
            userInfo: [extensionDiagnosticRecordsUserInfoKey: data],
            deliverImmediately: true
        )
    }

    public static func diagnosticRecord(from notification: Notification) -> ExtensionDiagnosticRecord? {
        guard let data = notification.userInfo?[extensionDiagnosticRecordUserInfoKey] as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(ExtensionDiagnosticRecord.self, from: data)
    }

    public static func diagnosticRecords(from notification: Notification) -> [ExtensionDiagnosticRecord] {
        guard let data = notification.userInfo?[extensionDiagnosticRecordsUserInfoKey] as? Data else {
            return []
        }
        return (try? JSONDecoder().decode([ExtensionDiagnosticRecord].self, from: data)) ?? []
    }

    public static func mergeExtensionDiagnosticsLocally(_ incomingRecords: [ExtensionDiagnosticRecord]) {
        guard !incomingRecords.isEmpty else { return }

        diagnosticLock.lock()
        var recordsByID: [UUID: ExtensionDiagnosticRecord] = [:]
        for record in loadDiagnosticRecords() {
            recordsByID[record.id] = record
        }
        for record in incomingRecords {
            recordsByID[record.id] = record
        }

        let mergedRecords = recordsByID.values
            .sorted { $0.timestamp < $1.timestamp }
            .suffix(maximumDiagnosticRecordCount)
        saveDiagnosticRecords(Array(mergedRecords))
        diagnosticLock.unlock()
    }

    public static func getLocalExtensionDiagnostics(limit: Int = 30) -> [ExtensionDiagnosticRecord] {
        diagnosticLock.lock()
        let records = loadDiagnosticRecords()
        diagnosticLock.unlock()
        return Array(records.suffix(max(0, limit)))
    }

    private static func loadDiagnosticRecords() -> [ExtensionDiagnosticRecord] {
        guard let data = UserDefaults.standard.data(forKey: extensionDiagnosticBufferKey),
              let records = try? JSONDecoder().decode([ExtensionDiagnosticRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func saveDiagnosticRecords(_ records: [ExtensionDiagnosticRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: extensionDiagnosticBufferKey)
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
        let enabled = Set(getEnabledFileTemplates().map { $0.fileExtension })
        var userInfo: [String: Any] = ["enabledExtensions": Array(enabled)]

        if let data = sharedSuite?.data(forKey: templateCacheKey) {
            userInfo["templateRecords"] = data
        }

        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.LimeBits.RightHere.SettingsChanged"),
            object: nil,
            userInfo: userInfo,
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
            Notification.Name("com.LimeBits.RightHere.SettingsChanged"),
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

public struct ExtensionDiagnosticRecord: Codable, Hashable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let message: String

    public init(id: UUID = UUID(), timestamp: Date, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
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
