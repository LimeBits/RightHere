import AppKit
import Foundation

/// Looks up a localized string from the shared catalog.
///
/// This file is compiled into both the main app and the FinderSync extension,
/// and `Localizable.xcstrings` is listed as a resource in both targets. Using
/// `Bundle.main` therefore resolves to whichever bundle the caller runs in:
/// the app bundle in the app, the .appex bundle in the extension.
func L(_ key: String, _ comment: String = "") -> String {
    NSLocalizedString(key, bundle: .main, comment: comment)
}

/// Formatted variant of `L(_:_:)`.
func L(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: arguments)
}

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
    public static let shortcutOpenRequestNotificationName = Notification.Name("com.LimeBits.RightHere.ShortcutOpenRequest")
    public static let templateCacheKey = "templateCache"
    public static let localTemplateCacheKey = "localTemplateCache"
    public static let localDisabledTypesKey = "localDisabledFileTypes"
    public static let finderMenuDisabledKey = "finderMenuDisabled"
    public static let shortcutLocationsKey = "shortcutLocations"
    public static let localShortcutLocationsKey = "localShortcutLocations"
    public static let shortcutLocationsInitializedKey = "shortcutLocationsInitialized"
    public static let localShortcutLocationsInitializedKey = "localShortcutLocationsInitialized"
    // Legacy key name; now gates the whole "Open Here" submenu, not just Terminal.
    public static let openInTerminalEnabledKey = "openInTerminalEnabled"
    public static let shortcutLocationsEnabledKey = "shortcutLocationsEnabled"
    public static let devToolsEnabledKey = "devToolsEnabled"
    public static let openHereAppsKey = "openHereApps"
    public static let localOpenHereAppsKey = "localOpenHereApps"
    public static let openHereAppsInitializedKey = "openHereAppsInitialized"
    public static let localOpenHereAppsInitializedKey = "localOpenHereAppsInitialized"
    private static let extensionDiagnosticBufferKey = "extensionDiagnosticBuffer"
    private static let extensionDiagnosticRecordUserInfoKey = "record"
    private static let extensionDiagnosticRecordsUserInfoKey = "records"
    private static let shortcutOpenRequestUserInfoKey = "request"
    private static let pendingShortcutOpenRequestKey = "pendingShortcutOpenRequest"
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

    public static func isOpenInTerminalEnabled() -> Bool {
        if let sharedSuite, sharedSuite.object(forKey: openInTerminalEnabledKey) != nil {
            return sharedSuite.bool(forKey: openInTerminalEnabledKey)
        }

        if UserDefaults.standard.object(forKey: openInTerminalEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: openInTerminalEnabledKey)
        }

        return true
    }

    public static func setOpenInTerminalEnabled(_ isEnabled: Bool) {
        sharedSuite?.set(isEnabled, forKey: openInTerminalEnabledKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(isEnabled, forKey: openInTerminalEnabledKey)
        notifySettingsChanged()
        notifyLocalSettingsChanged()
    }

    public static func areShortcutLocationsEnabled() -> Bool {
        if let sharedSuite, sharedSuite.object(forKey: shortcutLocationsEnabledKey) != nil {
            return sharedSuite.bool(forKey: shortcutLocationsEnabledKey)
        }

        if UserDefaults.standard.object(forKey: shortcutLocationsEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: shortcutLocationsEnabledKey)
        }

        return true
    }

    public static func setShortcutLocationsEnabled(_ isEnabled: Bool) {
        sharedSuite?.set(isEnabled, forKey: shortcutLocationsEnabledKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(isEnabled, forKey: shortcutLocationsEnabledKey)
        notifySettingsChanged()
        notifyLocalSettingsChanged()
    }

    public static func areDevToolsEnabled() -> Bool {
        if let sharedSuite, sharedSuite.object(forKey: devToolsEnabledKey) != nil {
            return sharedSuite.bool(forKey: devToolsEnabledKey)
        }

        if UserDefaults.standard.object(forKey: devToolsEnabledKey) != nil {
            return UserDefaults.standard.bool(forKey: devToolsEnabledKey)
        }

        return true
    }

    public static func setDevToolsEnabled(_ isEnabled: Bool) {
        sharedSuite?.set(isEnabled, forKey: devToolsEnabledKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(isEnabled, forKey: devToolsEnabledKey)
        notifySettingsChanged()
        notifyLocalSettingsChanged()
    }

    /// Stored on/off state for every known app, whether installed or not, so a
    /// user's choice survives uninstalling and reinstalling an editor.
    public static func getOpenHereAppSettings() -> [OpenHereAppSetting] {
        if sharedSuite?.bool(forKey: openHereAppsInitializedKey) == true {
            return mergeWithKnownApps(loadOpenHereAppSettings(from: sharedSuite, key: openHereAppsKey))
        }

        return defaultOpenHereAppSettings
    }

    public static func getLocalOpenHereAppSettings() -> [OpenHereAppSetting] {
        if UserDefaults.standard.bool(forKey: localOpenHereAppsInitializedKey) {
            return mergeWithKnownApps(
                loadOpenHereAppSettings(from: UserDefaults.standard, key: localOpenHereAppsKey)
            )
        }

        return getOpenHereAppSettings()
    }

    public static func setOpenHereAppSettings(_ settings: [OpenHereAppSetting]) {
        let merged = mergeWithKnownApps(settings)
        saveOpenHereAppSettings(merged, defaults: sharedSuite, key: openHereAppsKey)
        saveOpenHereAppSettings(merged, defaults: UserDefaults.standard, key: localOpenHereAppsKey)
        sharedSuite?.set(true, forKey: openHereAppsInitializedKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(true, forKey: localOpenHereAppsInitializedKey)
        notifySettingsChanged()
        notifyLocalSettingsChanged()
    }

    /// Apps that should appear in the Finder submenu: enabled by the user and
    /// currently installed on this machine.
    public static func getActiveOpenHereApps() -> [OpenHereApp] {
        getOpenHereAppSettings()
            .filter { $0.isEnabled && $0.app.isInstalled }
            .map { $0.app }
    }

    private static func mergeWithKnownApps(_ settings: [OpenHereAppSetting]) -> [OpenHereAppSetting] {
        let storedByApp = Dictionary(settings.map { ($0.app, $0.isEnabled) }, uniquingKeysWith: { _, last in last })
        return OpenHereApp.allCases.map { app in
            OpenHereAppSetting(app: app, isEnabled: storedByApp[app] ?? app.isEnabledByDefault)
        }
    }

    private static var defaultOpenHereAppSettings: [OpenHereAppSetting] {
        OpenHereApp.allCases.map { OpenHereAppSetting(app: $0, isEnabled: $0.isEnabledByDefault) }
    }

    private static func loadOpenHereAppSettings(
        from defaults: UserDefaults?,
        key: String
    ) -> [OpenHereAppSetting] {
        guard let data = defaults?.data(forKey: key),
              let settings = try? JSONDecoder().decode([OpenHereAppSetting].self, from: data) else {
            return []
        }

        return settings
    }

    private static func saveOpenHereAppSettings(
        _ settings: [OpenHereAppSetting],
        defaults: UserDefaults?,
        key: String
    ) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults?.set(data, forKey: key)
        defaults?.synchronize()
    }

    public static func getShortcutLocations() -> [ShortcutLocation] {
        if sharedSuite?.bool(forKey: shortcutLocationsInitializedKey) == true {
            return loadShortcutLocations(from: sharedSuite, key: shortcutLocationsKey)
        }

        return defaultShortcutLocations
    }

    public static func getLocalShortcutLocations() -> [ShortcutLocation] {
        if UserDefaults.standard.bool(forKey: localShortcutLocationsInitializedKey) {
            return loadShortcutLocations(from: UserDefaults.standard, key: localShortcutLocationsKey)
        }

        return getShortcutLocations()
    }

    public static func setShortcutLocations(_ locations: [ShortcutLocation]) {
        let normalizedLocations = locations.map { $0.normalized() }.sorted()
        saveShortcutLocations(normalizedLocations, defaults: sharedSuite, key: shortcutLocationsKey)
        saveShortcutLocations(normalizedLocations, defaults: UserDefaults.standard, key: localShortcutLocationsKey)
        sharedSuite?.set(true, forKey: shortcutLocationsInitializedKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(true, forKey: localShortcutLocationsInitializedKey)
        notifySettingsChanged()
        notifyLocalSettingsChanged()
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

    public static func requestShortcutOpen(_ location: ShortcutLocation) {
        let request = ShortcutOpenRequest(location: location.normalized())
        guard let data = try? JSONEncoder().encode(request) else { return }

        sharedSuite?.set(data, forKey: pendingShortcutOpenRequestKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.set(data, forKey: pendingShortcutOpenRequestKey)

        DistributedNotificationCenter.default().postNotificationName(
            shortcutOpenRequestNotificationName,
            object: nil,
            userInfo: [shortcutOpenRequestUserInfoKey: data],
            deliverImmediately: true
        )
    }

    public static func shortcutOpenRequest(from notification: Notification) -> ShortcutOpenRequest? {
        guard let data = notification.userInfo?[shortcutOpenRequestUserInfoKey] as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(ShortcutOpenRequest.self, from: data)
    }

    public static func consumePendingShortcutOpenRequest() -> ShortcutOpenRequest? {
        let data = sharedSuite?.data(forKey: pendingShortcutOpenRequestKey)
            ?? UserDefaults.standard.data(forKey: pendingShortcutOpenRequestKey)
        sharedSuite?.removeObject(forKey: pendingShortcutOpenRequestKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.removeObject(forKey: pendingShortcutOpenRequestKey)

        guard let data else { return nil }
        return try? JSONDecoder().decode(ShortcutOpenRequest.self, from: data)
    }

    public static func clearPendingShortcutOpenRequest(id: UUID) {
        let data = sharedSuite?.data(forKey: pendingShortcutOpenRequestKey)
            ?? UserDefaults.standard.data(forKey: pendingShortcutOpenRequestKey)
        guard let data,
              let existing = try? JSONDecoder().decode(ShortcutOpenRequest.self, from: data),
              existing.id == id else {
            return
        }

        sharedSuite?.removeObject(forKey: pendingShortcutOpenRequestKey)
        sharedSuite?.synchronize()
        UserDefaults.standard.removeObject(forKey: pendingShortcutOpenRequestKey)
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

        if let data = sharedSuite?.data(forKey: shortcutLocationsKey) {
            userInfo["shortcutLocations"] = data
        }

        if let data = sharedSuite?.data(forKey: openHereAppsKey) {
            userInfo["openHereApps"] = data
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

        if let data = UserDefaults.standard.data(forKey: localShortcutLocationsKey) {
            userInfo["shortcutLocations"] = data
        }

        if let data = UserDefaults.standard.data(forKey: localOpenHereAppsKey) {
            userInfo["openHereApps"] = data
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

    private static func loadShortcutLocations(from defaults: UserDefaults?, key: String) -> [ShortcutLocation] {
        guard let data = defaults?.data(forKey: key),
              let locations = try? JSONDecoder().decode([ShortcutLocation].self, from: data) else {
            return []
        }

        return locations.map { $0.normalized() }.sorted()
    }

    private static func saveShortcutLocations(_ locations: [ShortcutLocation], defaults: UserDefaults?, key: String) {
        guard let data = try? JSONEncoder().encode(locations.sorted()) else { return }
        defaults?.set(data, forKey: key)
        defaults?.synchronize()
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

    private static var defaultShortcutLocations: [ShortcutLocation] {
        guard let pw = getpwuid(getuid()) else { return [] }
        let homePath = String(cString: pw.pointee.pw_dir)
        let candidates: [(String, String)] = [
            (L("Home"), homePath),
            (L("Downloads"), "\(homePath)/Downloads"),
            (L("Documents"), "\(homePath)/Documents"),
            (L("Desktop"), "\(homePath)/Desktop")
        ]

        return candidates.enumerated().map { index, item in
            ShortcutLocation(
                displayName: item.0,
                path: item.1,
                kind: .directory,
                isEnabled: true,
                sortOrder: index
            )
        }
    }
}

public struct ShortcutLocation: Codable, Hashable, Identifiable, Comparable {
    public enum Kind: String, Codable, Hashable {
        case file
        case directory
        case unknown
    }

    public let id: UUID
    public var displayName: String
    public var path: String
    public var kind: Kind
    public var isEnabled: Bool
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        kind: Kind = .unknown,
        isEnabled: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.kind = kind
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }

    public var expandedPath: String {
        Self.expandPath(path)
    }

    public var url: URL {
        URL(fileURLWithPath: expandedPath, isDirectory: kind == .directory)
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: expandedPath)
    }

    public func normalized() -> ShortcutLocation {
        let expandedPath = Self.expandPath(path)
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)
        let inferredKind: Kind
        if exists {
            inferredKind = isDirectory.boolValue ? .directory : .file
        } else {
            inferredKind = kind
        }

        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = URL(fileURLWithPath: expandedPath).lastPathComponent
        return ShortcutLocation(
            id: id,
            displayName: normalizedName.isEmpty ? (fallbackName.isEmpty ? expandedPath : fallbackName) : normalizedName,
            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: inferredKind,
            isEnabled: isEnabled,
            sortOrder: sortOrder
        )
    }

    public static func expandPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath == "~" {
            return NSHomeDirectory()
        }

        if trimmedPath.hasPrefix("~/") {
            return NSHomeDirectory() + String(trimmedPath.dropFirst())
        }

        return (trimmedPath as NSString).expandingTildeInPath
    }

    public static func < (lhs: ShortcutLocation, rhs: ShortcutLocation) -> Bool {
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }
}

/// An app that can be launched with a directory as its working directory.
public enum OpenHereApp: String, CaseIterable, Identifiable, Codable {
    case terminal
    case iTerm
    case warp
    case vscode
    case cursor

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        // Only Terminal has a translatable name; the others are product names.
        case .terminal: return L("Terminal")
        case .iTerm: return "iTerm"
        case .warp: return "Warp"
        case .vscode: return "VS Code"
        case .cursor: return "Cursor"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iTerm: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .vscode: return "com.microsoft.VSCode"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        }
    }

    /// Terminal.app always ships with macOS, so it needs no install check and is
    /// the one entry enabled by default.
    public var isBuiltIn: Bool {
        self == .terminal
    }

    public var isEnabledByDefault: Bool {
        isBuiltIn
    }

    public var sortOrder: Int {
        OpenHereApp.allCases.firstIndex(of: self) ?? 0
    }

    /// Resolves the installed app bundle, or nil when the app is not present.
    public func installedApplicationURL() -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return url
        }

        // Terminal lives outside /Applications and older systems may not answer
        // the bundle-identifier lookup for it.
        if self == .terminal {
            let fallback = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            if FileManager.default.fileExists(atPath: fallback.path) {
                return fallback
            }
        }

        return nil
    }

    public var isInstalled: Bool {
        installedApplicationURL() != nil
    }
}

/// Per-app on/off state for the "Open Here" submenu.
public struct OpenHereAppSetting: Codable, Hashable, Identifiable {
    public let app: OpenHereApp
    public var isEnabled: Bool

    public var id: String { app.rawValue }

    public init(app: OpenHereApp, isEnabled: Bool) {
        self.app = app
        self.isEnabled = isEnabled
    }
}

public enum DevToolAction: String, CaseIterable, Identifiable, Codable {
    case fullPath
    case fileName
    case fileNameWithoutExtension
    case containingDirectoryPath
    case markdownLink

    public var id: String { rawValue }

    public var menuTitle: String {
        switch self {
        case .fullPath: return L("Copy Full Path")
        case .fileName: return L("Copy File Name")
        case .fileNameWithoutExtension: return L("Copy File Name Without Extension")
        case .containingDirectoryPath: return L("Copy Containing Folder Path")
        case .markdownLink: return L("Copy Markdown Link")
        }
    }

    /// Builds the clipboard string for the given targets, one result per line.
    /// Returns nil when no target produces a usable value.
    public static func clipboardText(for action: DevToolAction, targets: [URL]) -> String? {
        var lines: [String] = []
        var seenLines = Set<String>()

        for url in targets {
            guard let line = action.line(for: url), !line.isEmpty else { continue }
            // Only the containing-directory action can legitimately repeat itself
            // across a multi-selection inside the same folder.
            if action == .containingDirectoryPath {
                guard seenLines.insert(line).inserted else { continue }
            }
            lines.append(line)
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func line(for url: URL) -> String? {
        let standardized = url.standardizedFileURL

        switch self {
        case .fullPath:
            return standardized.path
        case .fileName:
            return standardized.lastPathComponent
        case .fileNameWithoutExtension:
            return standardized.deletingPathExtension().lastPathComponent
        case .containingDirectoryPath:
            // A folder is its own "location"; only files resolve to their parent.
            if DevToolAction.isDirectory(standardized) {
                return standardized.path
            }
            return standardized.deletingLastPathComponent().path
        case .markdownLink:
            let name = DevToolAction.escapeMarkdownText(standardized.lastPathComponent)
            guard let encoded = DevToolAction.fileURLString(for: standardized) else { return nil }
            return "[\(name)](\(encoded))"
        }
    }

    /// Whether this action makes sense for the given selection. Keeps the submenu
    /// free of entries that would duplicate another line for the same target.
    public func isApplicable(to targets: [URL]) -> Bool {
        guard !targets.isEmpty else { return false }

        switch self {
        case .containingDirectoryPath:
            // Every target being a folder would just repeat Copy Full Path.
            return targets.contains { !DevToolAction.isDirectory($0) }
        case .fileNameWithoutExtension:
            return targets.contains { !$0.standardizedFileURL.pathExtension.isEmpty }
        case .fullPath, .fileName, .markdownLink:
            return true
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        if url.hasDirectoryPath {
            return true
        }

        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func fileURLString(for url: URL) -> String? {
        var allowed = CharacterSet.urlPathAllowed
        // Percent-encode characters that terminate or nest a Markdown link target.
        allowed.remove(charactersIn: "()#?")
        guard let encodedPath = url.path.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }

        return "file://\(encodedPath)"
    }

    private static func escapeMarkdownText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }
}

public struct ShortcutOpenRequest: Codable, Hashable, Identifiable {
    public let id: UUID
    public let location: ShortcutLocation
    public let requestedAt: Date

    public init(id: UUID = UUID(), location: ShortcutLocation, requestedAt: Date = Date()) {
        self.id = id
        self.location = location
        self.requestedAt = requestedAt
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
        case "txt": return L("Plain Text (.txt)")
        case "md": return L("Markdown (.md)")
        case "docx": return L("Word Document (.docx)")
        case "xlsx": return L("Excel Worksheet (.xlsx)")
        case "pptx": return L("PowerPoint Presentation (.pptx)")
        case "rtf": return L("Rich Text (.rtf)")
        default: return L("%1$@ File (.%2$@)", fileExtension.uppercased(), fileExtension)
        }
    }

    public var defaultFileName: String {
        switch fileExtension {
        case "txt": return L("New Text Document")
        case "md": return L("New Markdown Document")
        case "docx": return L("New Word Document")
        case "xlsx": return L("New Excel Worksheet")
        case "pptx": return L("New PowerPoint Presentation")
        case "rtf": return L("New Rich Text Document")
        default: return L("New %@ File", fileExtension.uppercased())
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

    public var fileExtension: String {
        return self.rawValue
    }
}
