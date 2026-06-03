import Foundation

public struct TemplateAssets {
    // Minimal empty .docx file (Base64)
    public static let docxBase64 = "UEsDBBQAAAAIADOmw1zXeYTq8QAAALgBAAATAAAAW0NvbnRlbnRfVHlwZXNdLnhtbH2QzU7DMBCE730Ky9cqccoBIZSkB36OwKE8wMreJFb9J69b2rdn00KREOVozXwz62nXB+/EHjPZGDq5qhspMOhobBg7+b55ru6koALBgIsBO3lEkut+0W6OCUkwHKiTUynpXinSE3qgOiYMrAwxeyj8zKNKoLcworppmlulYygYSlXmDNkvhGgfcYCdK+LpwMr5loyOpHg4e+e6TkJKzmoorKt9ML+Kqq+SmsmThyabaMkGqa6VzOL1jh/0lSfK1qB4g1xewLNRfcRslIl65xmu/0/649o4DFbjhZ/TUo4aiXh77+qL4sGG71+06jR8/wlQSwMEFAAAAAgAM6bDXCAbhuqyAAAALgEAAAsAAABfcmVscy8ucmVsc43Puw6CMBQG4J2naM4uBQdjDIXFmLAafICmPZRGeklbL7y9HRzEODie23fyN93TzOSOIWpnGdRlBQStcFJbxeAynDZ7IDFxK/nsLDJYMELXFs0ZZ57yTZy0jyQjNjKYUvIHSqOY0PBYOo82T0YXDE+5DIp6Lq5cId1W1Y6GTwPagpAVS3rJIPSyBjIsHv/h3ThqgUcnbgZt+vHlayPLPChMDB4uSCrf7TKzQHNKuorZvgBQSwMEFAAAAAgAM6bDXJ/dzJKSAAAAswAAABEAAAB3b3JkL2RvY3VtZW50LnhtbDWNQQ7CIBBF9z0Fmb2lujCmKXTnCfQACGNtUmYIg9beXkx09f/PT94bxndc1AuzzEwG9m0HCslzmGkycL2cdydQUhwFtzChgQ0FRtsMax/YPyNSUZVA0q8GHqWkXmvxD4xOWk5I9btzjq7UmSe9cg4ps0eRKoiLPnTdUUc3E9hGqUq9cdhszaTtoH+z+ba/zn4AUEsDBBQAAAAIADOmw1yMDoXQfQAAAJ0AAAAcAAAAd29yZC9fcmVscy9kb2N1bWVudC54bWwucmVsc1XMQQ7CIBCF4b2nILO3oAtjTGl3PYDRA0zoCI0wEIYYvb0sdfny533j/E5RvajKltnCYTCgiF1eN/YW7rdlfwYlDXnFmJksfEhgnnbjlSK2/pGwFVEdYbEQWisXrcUFSihDLsS9PHJN2PqsXhd0T/Skj8acdP01oKP6T52+UEsBAhQDFAAAAAgAM6bDXNd5hOrxAAAAuAEAABMAAAAAAAAAAAAAAIABAAAAAFtDb250ZW50X1R5cGVzXS54bWxQSwECFAMUAAAACAAzpsNcIBuG6rIAAAAuAQAACwAAAAAAAAAAAAAAgAEiAQAAX3JlbHMvLnJlbHNQSwECFAMUAAAACAAzpsNcn93MkpIAAACzAAAAEQAAAAAAAAAAAAAAgAH9AQAAd29yZC9kb2N1bWVudC54bWxQSwECFAMUAAAACAAzpsNcjA6F0H0AAACdAAAAHAAAAAAAAAAAAAAAgAG+AgAAd29yZC9fcmVscy9kb2N1bWVudC54bWwucmVsc1BLBQYAAAAABAAEAAMBAAB1AwAAAAA="
    
    // Minimal empty .xlsx file (Base64)
    public static let xlsxBase64 = "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"
    
    // Minimal empty .pptx file (Base64)
    public static let pptxBase64 = "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"
    
    public static func initializeDefaultTemplates() {
        guard let templatesDir = SharedDefaults.templatesDirectoryURL else {
            print("Failed to get shared templates directory")
            return
        }
        
        let fileManager = FileManager.default
        
        // Ensure templates directory exists
        if !fileManager.fileExists(atPath: templatesDir.path) {
            do {
                try fileManager.createDirectory(at: templatesDir, withIntermediateDirectories: true, attributes: nil)
                print("Created templates directory: \(templatesDir.path)")
            } catch {
                print("Failed to create templates directory: \(error)")
                return
            }
        }
        
        // Define templates to initialize
        let templates: [(filename: String, base64: String?, isText: Bool, textContent: String)] = [
            ("template.txt", nil, true, ""),
            ("template.md", nil, true, ""),
            ("template.docx", docxBase64, false, ""),
            ("template.xlsx", xlsxBase64, false, ""),
            ("template.pptx", pptxBase64, false, "")
        ]
        
        for t in templates {
            let fileURL = templatesDir.appendingPathComponent(t.filename)
            
            // Check if file already exists so we don't overwrite user customizations
            if !fileManager.fileExists(atPath: fileURL.path) {
                if t.isText {
                    do {
                        try t.textContent.write(to: fileURL, atomically: true, encoding: .utf8)
                        print("Initialized text template: \(t.filename)")
                    } catch {
                        print("Failed to write template \(t.filename): \(error)")
                    }
                } else if let base64String = t.base64,
                          let data = Data(base64Encoded: base64String) {
                    do {
                        try data.write(to: fileURL)
                        print("Initialized binary template: \(t.filename)")
                    } catch {
                        print("Failed to write template \(t.filename): \(error)")
                    }
                }
            }
        }
    }
}
