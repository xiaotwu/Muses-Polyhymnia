import Foundation
import Testing
@testable import Muses

@Suite("Muses resource bundle resolution")
struct MusesResourcesTests {
    @Test("Packaged applications resolve either supported resource bundle name",
          arguments: ["Muses_Muses.bundle", "Muses-Polyhymnia_Muses.bundle"])
    func packagedAliases(alias: String) throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: "Packaged.app")
            let moduleURL = try fixture.module(named: alias, in: appURL, marker: "packaged")
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })
            let resource = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))

            #expect(resolved.bundleURL.standardizedFileURL == moduleURL.standardizedFileURL)
            #expect(try Data(contentsOf: resource) == Data("packaged".utf8))
            #expect(fallbackCalls == 0)
        }
    }

    @Test("The canonical resource bundle name wins when both aliases exist")
    func canonicalAliasHasPriority() throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: "Packaged.app")
            let canonical = try fixture.module(
                named: "Muses_Muses.bundle", in: appURL, marker: "canonical")
            _ = try fixture.module(
                named: "Muses-Polyhymnia_Muses.bundle", in: appURL, marker: "secondary")
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })
            let resource = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))

            #expect(resolved.bundleURL.standardizedFileURL == canonical.standardizedFileURL)
            #expect(try Data(contentsOf: resource) == Data("canonical".utf8))
            #expect(fallbackCalls == 0)
        }
    }

    @Test("Moving an application preserves lookup relative to its current bundle")
    func movedApplication() throws {
        try withFixture { fixture in
            let original = try fixture.application(named: "Original.app")
            _ = try fixture.module(named: "Muses_Muses.bundle", in: original, marker: "moved")
            let moved = fixture.root.appendingPathComponent("Relocated.app", isDirectory: true)
            try FileManager.default.moveItem(at: original, to: moved)
            let main = try #require(Bundle(url: moved))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })
            let resource = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))

            #expect(resource.path.hasPrefix(moved.path + "/"))
            #expect(!FileManager.default.fileExists(atPath: original.path))
            #expect(try Data(contentsOf: resource) == Data("moved".utf8))
            #expect(fallbackCalls == 0)
        }
    }

    @Test("Applications without either alias return nil without a development fallback",
          arguments: ["Missing.app", "Missing.APP"])
    func missingPackagedAliases(name: String) throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: name)
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            }

            #expect(resolved == nil)
            #expect(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved) == nil)
            #expect(fallbackCalls == 0)
        }
    }

    @Test("A packaged bundle missing a required resource returns nil without escaping to development")
    func missingPackagedResource() throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: "Incomplete.app")
            _ = try fixture.module(named: "Muses_Muses.bundle", in: appURL, marker: nil)
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })

            #expect(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved) == nil)
            #expect(fallbackCalls == 0)
        }
    }

    @Test("A development host evaluates its fallback exactly once")
    func developmentFallback() throws {
        try withFixture { fixture in
            let hostURL = try fixture.bundle(
                at: fixture.root.appendingPathComponent("CommandLineHost.bundle", isDirectory: true),
                packageType: "BNDL")
            let host = try #require(Bundle(url: hostURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0

            let resolved = try #require(MusesResources.resolveBundle(in: host) {
                fallbackCalls += 1
                return development
            })
            let resource = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))

            #expect(resolved.bundleURL.standardizedFileURL == development.bundleURL.standardizedFileURL)
            #expect(try Data(contentsOf: resource) == Data("development".utf8))
            #expect(fallbackCalls == 1)
        }
    }

    @Test("Flat copied resources remain available beside a Contents runtime shell without bundle Info")
    func flatResourcesWithContentsShell() throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: "Flat.app")
            let moduleURL = try fixture.module(
                named: "Muses_Muses.bundle", in: appURL, marker: "flat", flatResources: true)
            // The CI copy has no bundle Info and carries runtime files in its Contents shell.
            try FileManager.default.removeItem(at: moduleURL.appendingPathComponent("Contents/Info.plist"))
            try fixture.write("runtime", to: moduleURL
                .appendingPathComponent("Contents/Resources/Resources/yt-dlp"))
            try fixture.write("flat-helper", to: moduleURL.appendingPathComponent("Resources/fixture-helper"))
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0
            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })
            let shell = moduleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
            #expect(resolved.resourceURL?.standardizedFileURL == shell.standardizedFileURL)
            #expect(resolved.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization") == nil)

            let locale = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))
            let runtime = try #require(MusesResources.url(
                forResource: "yt-dlp", withExtension: nil, subdirectory: "Resources", in: resolved))
            let flatHelper = try #require(MusesResources.url(
                forResource: "fixture-helper", withExtension: nil, subdirectory: "Resources", in: resolved))

            #expect(locale.standardizedFileURL == moduleURL
                .appendingPathComponent("Resources/Localization/zh-Hant.json").standardizedFileURL)
            #expect(!FileManager.default.fileExists(atPath: moduleURL
                .appendingPathComponent("Contents/Info.plist").path))
            #expect(try Data(contentsOf: locale) == Data("flat".utf8))
            #expect(try Data(contentsOf: runtime) == Data("runtime".utf8))
            #expect(try Data(contentsOf: flatHelper) == Data("flat-helper".utf8))
            #expect(fallbackCalls == 0)
        }
    }

    @Test("Foundation resource lookup takes priority over a flat copy")
    func foundationLookupHasPriority() throws {
        try withFixture { fixture in
            let appURL = try fixture.application(named: "BothLayouts.app")
            let moduleURL = try fixture.module(
                named: "Muses_Muses.bundle", in: appURL, marker: "foundation")
            try fixture.write("flat-decoy", to: moduleURL
                .appendingPathComponent("Resources/Localization/zh-Hant.json"))
            let main = try #require(Bundle(url: appURL))
            let development = try fixture.developmentBundle()
            var fallbackCalls = 0
            let resolved = try #require(MusesResources.resolveBundle(in: main) {
                fallbackCalls += 1
                return development
            })
            let foundationURL = try #require(resolved.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization"))
            let resource = try #require(MusesResources.url(
                forResource: "zh-Hant", withExtension: "json",
                subdirectory: "Resources/Localization", in: resolved))

            #expect(resource.standardizedFileURL == foundationURL.standardizedFileURL)
            #expect(try Data(contentsOf: resource) == Data("foundation".utf8))
            #expect(fallbackCalls == 0)
        }
    }

    private func withFixture(_ body: (ResourceFixture) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appendingPathComponent("muses-resources-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(ResourceFixture(root: root))
    }
}

private struct ResourceFixture {
    let root: URL

    func application(named name: String) throws -> URL {
        try bundle(at: root.appendingPathComponent(name, isDirectory: true), packageType: "APPL")
    }

    func bundle(at url: URL, packageType: String) throws -> URL {
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contents.appendingPathComponent("Resources", isDirectory: true),
            withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.muses.tests.resources.\(UUID().uuidString.lowercased())",
            "CFBundleName": "Resource Fixture",
            "CFBundlePackageType": packageType,
            "CFBundleVersion": "1",
            "CFBundleDevelopmentRegion": "en",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }

    func module(named name: String, in app: URL, marker: String?, flatResources: Bool = false) throws -> URL {
        let url = try bundle(
            at: app.appendingPathComponent("Contents/Resources/\(name)", isDirectory: true),
            packageType: "BNDL")
        if let marker {
            let directory = flatResources ? url : url.appendingPathComponent("Contents/Resources")
            try write(marker, to: directory.appendingPathComponent("Resources/Localization/zh-Hant.json"))
        }
        return url
    }

    func developmentBundle() throws -> Bundle {
        let url = try bundle(
            at: root.appendingPathComponent("DevelopmentResources.bundle", isDirectory: true),
            packageType: "BNDL")
        try write("development", to: url
            .appendingPathComponent("Contents/Resources/Resources/Localization/zh-Hant.json"))
        return try #require(Bundle(url: url))
    }

    func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
    }
}
