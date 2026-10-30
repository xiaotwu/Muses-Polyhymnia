import Foundation

/// Resolve packaged resources before SwiftPM's build-machine-specific accessor.
enum MusesResources {
    static let bundle: Bundle? = resolveBundle(in: .main) { Bundle.module }

    /// SwiftPM accessor layouts differ between toolchains. Shipping apps carry
    /// these aliases in Contents/Resources and must never try a checkout path.
    static func resolveBundle(in mainBundle: Bundle, developmentBundle: () -> Bundle) -> Bundle? {
        if let resources = mainBundle.resourceURL {
            for name in ["Muses_Muses.bundle", "Muses-Polyhymnia_Muses.bundle"] {
                if let bundle = Bundle(url: resources.appendingPathComponent(name, isDirectory: true)) {
                    return bundle
                }
            }
        }
        guard mainBundle.bundleURL.pathExtension.lowercased() != "app" else { return nil }
        // The generated accessor may fatalError when its bundle is absent, so
        // evaluate it only for swift run/test after packaged lookup has failed.
        return developmentBundle()
    }

    static func url(forResource name: String, withExtension extensionName: String?,
                    subdirectory: String? = nil, in bundle: Bundle? = MusesResources.bundle) -> URL? {
        guard let bundle else { return nil }
        if let url = bundle.url(forResource: name, withExtension: extensionName, subdirectory: subdirectory) {
            return url
        }
        // A copied Resources directory can coexist with a nested Contents tree
        // used by bundled tools. Preserve the original flat SwiftPM layout too.
        var directory = bundle.bundleURL
        if let subdirectory { directory.appendPathComponent(subdirectory, isDirectory: true) }
        var url = directory.appendingPathComponent(name)
        if let extensionName { url.appendPathExtension(extensionName) }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { return nil }
        return url
    }

    /// Templates remain module resources; the installed app has injected Info.
    static let infoPlistURL = url(forResource: "Info", withExtension: "plist", subdirectory: "Resources")
    static let entitlementsURL = url(forResource: "Muses", withExtension: "entitlements", subdirectory: "Resources")
    static let islandMomentsFontURL = url(forResource: "IslandMoments-Regular", withExtension: "ttf", subdirectory: "Resources")
}
