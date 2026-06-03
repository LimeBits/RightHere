import SwiftUI

@main
struct RightHereApp: App {
    init() {
        // Initialize default templates in App Groups shared folder
        TemplateAssets.initializeDefaultTemplates()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 480, minHeight: 380)
        }
    }
}
