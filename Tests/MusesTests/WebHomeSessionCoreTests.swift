import Foundation
import Darwin
import Testing
import MusesWebHomeProtocol
@testable import MusesWebHomeCore

@Suite("Web Home cookie and identity isolation")
struct WebHomeSessionCoreTests {
    private let channelID = "UC1234567890123456789012"

    @Test("Cookie failure stages preserve the error code without exposing exporter data")
    func cookieFailureStages() async throws {
        let stages: [WebHomeCookieFailureStage] = [.exportExecutable, .exportLaunch, .exportNoOutput, .jarRead, .noAllowedDomain]
        for stage in stages {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let manager = try WebHomeCookieJarManager(rootDirectory: root, exporter: StageCookieExporter(stage: stage))
            let transport = QueueWebHomeTransport(responses: [])
            let result = await WebHomeCommand(cookieManager: manager,
                sessionClient: WebHomeSessionClient(transport: transport)).execute(request(expectedChannelID: channelID))
            #expect(result.error?.code == .cookieSourceUnavailable)
            #expect(result.error?.cookieFailureStage == stage)
            #expect(result.error?.identityPhase == nil)
            #expect(result.error?.message == nil)
            #expect(result.channelID == nil)
            #expect(result.sections.isEmpty)
            #expect(await transport.requests.isEmpty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        }
        let occupied = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: occupied) }
        try Data().write(to: occupied)
        do {
            _ = try WebHomeCookieJarManager(rootDirectory: occupied, exporter: StageCookieExporter(stage: .jarRead))
            Issue.record("An occupied workspace must fail before export")
        } catch let error as WebHomeCookieFailure {
            #expect(error.stage == .workspaceSetup)
        }
    }

    @Test("Cookie diagnostic IPC remains compatible with legacy and unknown stages")
    func cookieStageCompatibility() throws {
        let decoder = JSONDecoder()
        let legacy = try decoder.decode(WebHomeError.self, from: Data(#"{"code":"cookieSourceUnavailable"}"#.utf8))
        #expect(legacy.cookieFailureStage == nil)
        let future = try decoder.decode(WebHomeError.self, from: Data(#"{"code":"cookieSourceUnavailable","cookieFailureStage":"futureStage"}"#.utf8))
        #expect(future.cookieFailureStage == nil)
        #expect(future.code == .cookieSourceUnavailable)
        for stage in [WebHomeCookieFailureStage.exportNoOutput, .browserDatabaseLookup, .browserKeyLookup] {
            let error = WebHomeError(code: .cookieSourceUnavailable, cookieFailureStage: stage)
            #expect(try decoder.decode(WebHomeError.self, from: JSONEncoder().encode(error)) == error)
        }
        #expect(WebHomeProtocolVersion.current == 2)
    }

    @Test("Cookie stderr scanning recognizes only fixed upstream diagnostics within a bounded budget")
    func cookieDiagnosticWhitelist() {
        var database = CookieExportDiagnosticScanner()
        for byte in "ERROR: could not find chrome cookies database in ".utf8 {
            database.consume([byte])
        }
        database.consume(Data(repeating: 120, count: 100_000))
        database.finish()
        #expect(database.stage == .browserDatabaseLookup)
        var key = CookieExportDiagnosticScanner()
        key.consume("WARNING: find-generic-password failed\n".utf8)
        key.finish()
        #expect(key.stage == .browserKeyLookup)
        var decrypt = CookieExportDiagnosticScanner()
        decrypt.consume("WARNING: cannot decrypt v10 cookies: no key found\n".utf8)
        decrypt.finish()
        #expect(decrypt.stage == .browserKeyLookup)
        var unknown = CookieExportDiagnosticScanner()
        unknown.consume("ERROR: [Errno 13] Permission denied\nWARNING: find-generic-password failed extra unknown text\n".utf8)
        unknown.finish()
        #expect(unknown.stage == nil)
        var exhausted = CookieExportDiagnosticScanner()
        exhausted.consume(Data(repeating: 120, count: CookieExportDiagnosticScanner.maximumScanBytes))
        exhausted.consume("\nWARNING: find-generic-password failed\n".utf8)
        exhausted.finish()
        #expect(exhausted.stage == nil)
        var conflict = CookieExportDiagnosticScanner()
        conflict.consume("ERROR: could not find firefox cookies database in ignored\nWARNING: find-generic-password failed\n".utf8)
        conflict.finish()
        #expect(conflict.stage == nil)
    }

    @Test("Synthetic exporter diagnostics never replace valid jar success or jar-read failure")
    func cookieDiagnosticJarPrecedence() async throws {
        for variant in 0...2 {
            let root = temporaryRoot()
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let executable = root.appendingPathComponent("fake-exporter")
            let contents = variant == 0
                ? "printf '.youtube.com\\tTRUE\\t/\\tTRUE\\t0\\tSAPISID\\tsynthetic\\n' >> \"$destination\""
                : (variant == 1 ? "printf '\\377' > \"$destination\"" : "")
            let script = """
            #!/bin/sh
            destination=""
            while [ "$#" -gt 0 ]; do
              if [ "$1" = "--cookies" ]; then shift; destination="$1"; fi
              shift
            done
            printf 'WARNING: find-generic-password failed\n' >&2
            \(contents)
            exit 0
            """
            try Data(script.utf8).write(to: executable)
            #expect(chmod(executable.path, S_IRWXU) == 0)
            let manager = try WebHomeCookieJarManager(rootDirectory: root.appendingPathComponent("workspace"),
                exporter: ProcessYTDlpCookieExporter(executableURL: executable))
            do {
                let valid = try await manager.withCookieJar(source: .init(browserName: "chrome")) { jar in jar.sapisid != nil }
                #expect(variant == 0 && valid)
            } catch let error as WebHomeCookieFailure {
                #expect(error.stage == (variant == 1 ? .jarRead : .browserKeyLookup))
                #expect(variant != 0)
            }
        }
    }

    @Test("Exporter drains oversized stderr, ignores stdout and cancels without waiting on pipe EOF")
    func cookieDiagnosticProcessLifetime() async throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("fake-exporter")
        let destination = root.appendingPathComponent("synthetic.txt")
        try Data(WebHomeCookieJarManager.netscapeCookieHeader.utf8).write(to: destination)
        let script = """
        #!/bin/sh
        printf 'ERROR: could not find chrome cookies database in stdout-only\n'
        /usr/bin/head -c 200000 /dev/zero >&2
        printf '\nWARNING: find-generic-password failed\n' >&2
        exit 2
        """
        try Data(script.utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)
        let exporter = ProcessYTDlpCookieExporter(executableURL: executable)
        do {
            _ = try await exporter.export(browserSpecification: "chrome", to: destination)
            Issue.record("No produced jar must fail")
        } catch let error as WebHomeCookieFailure {
            #expect(error.stage == .exportNoOutput)
        }
        try Data("#!/bin/sh\nprintf 'ERROR: could not find chrome cookies database in synthetic-only\\n' >&2\nexit 1\n".utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)
        do {
            _ = try await exporter.export(browserSpecification: "chrome", to: destination)
            Issue.record("Missing database export must fail")
        } catch let error as WebHomeCookieFailure {
            #expect(error.stage == .browserDatabaseLookup)
        }
        try Data("#!/bin/sh\nexec /bin/sleep 30\n".utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)
        let operation = Task { try await exporter.export(browserSpecification: "chrome", to: destination) }
        try await Task.sleep(for: .milliseconds(100))
        let clock = ContinuousClock()
        let cancelledAt = clock.now
        operation.cancel()
        do {
            _ = try await operation.value
            Issue.record("Cancelled export must fail")
        } catch let error as WebHomeCoreError {
            #expect(error.code == .cancelled)
        }
        #expect(clock.now - cancelledAt < .seconds(5))
    }

    @Test("Exporter finishes when a synthetic descendant briefly retains the stderr pipe")
    func cookieDiagnosticInheritedPipe() async throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("fake-exporter")
        let destination = root.appendingPathComponent("synthetic.txt")
        let pidFile = root.appendingPathComponent("synthetic-child.pid")
        try Data(WebHomeCookieJarManager.netscapeCookieHeader.utf8).write(to: destination)
        let script = """
        #!/bin/sh
        /bin/sleep 3 &
        printf '%s' "$!" > '\(pidFile.path)'
        exit 2
        """
        try Data(script.utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)
        defer {
            if let text = try? String(contentsOf: pidFile, encoding: .utf8), let pid = Int32(text) {
                _ = kill(pid, SIGTERM)
            }
        }
        let clock = ContinuousClock()
        let started = clock.now
        do {
            _ = try await ProcessYTDlpCookieExporter(executableURL: executable)
                .export(browserSpecification: "chrome", to: destination)
            Issue.record("No produced jar must fail despite an inherited pipe")
        } catch let error as WebHomeCookieFailure {
            #expect(error.stage == .exportNoOutput)
        }
        #expect(clock.now - started < .seconds(1))
    }

    @Test("identity stage metadata is additive and unknown stages do not break error decoding")
    func identityStageCompatibility() throws {
        let decoder = JSONDecoder()
        let legacy = try decoder.decode(WebHomeError.self, from: Data(#"{"code":"identityUnavailable"}"#.utf8))
        #expect(legacy.identityPhase == nil)
        let future = try decoder.decode(WebHomeError.self, from: Data(#"{"code":"identityUnavailable","identityPhase":"futureStage"}"#.utf8))
        #expect(future.identityPhase == nil)
        #expect(future.code == .identityUnavailable)
        let error = WebHomeError(code: .identityUnavailable, identityPhase: .accountsList)
        #expect(try decoder.decode(WebHomeError.self, from: JSONEncoder().encode(error)) == error)
        #expect(WebHomeProtocolVersion.current == 2)
    }

    @Test("terminal identity stage survives helper IPC without changing error or strict account rejection")
    func terminalIdentityStages() async throws {
        let empty = response(Data("{}".utf8))
        let web = WebHomeTransportResponse(data: bootstrapHTML, statusCode: 200,
                                           finalURL: URL(string: "https://www.youtube.com/"))
        let accounts = response(Data(#"{"accountItem":{"isSelected":true,"channelHandle":{"runs":[{"text":"@Example"}]}}}"#.utf8))
        let wrong = response(identityJSON(channelID: "UC9999999999999999999999"))
        let cases: [(WebHomeIdentityPhase, WebHomeErrorCode, [WebHomeTransportResponse])] = [
            (.remixMenu, .accountMismatch, [response(bootstrapHTML), wrong]),
            (.webBootstrap, .identityUnavailable, [response(bootstrapHTML), empty,
                WebHomeTransportResponse(data: bootstrapHTML, statusCode: 200,
                                         finalURL: URL(string: "https://consent.youtube.com/"))]),
            (.webMenu, .accountMismatch, [response(bootstrapHTML), empty, web, wrong]),
            (.accountsList, .identityUnavailable, [response(bootstrapHTML), empty, web, empty, empty]),
            (.resolveURL, .identityUnavailable, [response(bootstrapHTML), empty, web, empty, accounts, empty])
        ]
        for (phase, code, responses) in cases {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let manager = try WebHomeCookieJarManager(rootDirectory: root,
                exporter: RecordingCookieExporter(cookieText: cookieText))
            let transport = QueueWebHomeTransport(responses: responses)
            let command = WebHomeCommand(cookieManager: manager,
                sessionClient: WebHomeSessionClient(transport: transport))
            let result = await command.execute(request(expectedChannelID: channelID))
            let decoded = try JSONDecoder().decode(WebHomeResponse.self, from: JSONEncoder().encode(result))
            #expect(decoded.error?.code == code)
            #expect(decoded.error?.identityPhase == phase)
            #expect(decoded.error?.message == nil)
            #expect(decoded.channelID == nil)
            #expect(decoded.sections.isEmpty)
            #expect(await transport.requests.count == responses.count)
        }
    }

    @Test("handle fallback requires exactly one selected account and an explicit resolved channel")
    func selectedHandleVerification() throws {
        let parser = WebHomeIdentityParser()
        let selected: [String: Any] = ["accountItem": ["isSelected": true, "channelHandle": ["runs": [["text": "@Example"]]]]]
        let unselected: [String: Any] = ["accountItem": ["isSelected": false, "channelHandle": ["runs": [["text": "@Other"]]]]]
        #expect(try parser.selectedHandle(from: JSONSerialization.data(withJSONObject: [selected, unselected])) == "@Example")
        #expect(throws: WebHomeCoreError.self) {
            try parser.selectedHandle(from: JSONSerialization.data(withJSONObject: [selected, selected]))
        }
        #expect(throws: WebHomeCoreError.self) {
            try parser.selectedHandle(from: JSONSerialization.data(withJSONObject: [unselected]))
        }
        #expect(try parser.resolvedChannelID(from: JSONSerialization.data(withJSONObject: ["endpoint": ["browseEndpoint": ["browseId": channelID]]])) == channelID)
        #expect(throws: WebHomeCoreError.self) {
            try parser.resolvedChannelID(from: JSONSerialization.data(withJSONObject: ["unrelated": ["browseId": channelID]]))
        }
    }

    @Test("temporary browser jar is 0600 inside a 0700 directory and is deleted")
    func temporaryJarPermissionsAndCleanup() async throws {
        let root = temporaryRoot()
        let exporter = RecordingCookieExporter(cookieText: cookieText)
        let manager = try WebHomeCookieJarManager(
            rootDirectory: root, exporter: exporter)

        let header = try await manager.withCookieJar(
            source: WebHomeCookieSourceDescriptor(browserName: "safari")) { jar in
                jar.header(for: "music.youtube.com")
            }
        let destination = try #require(await exporter.destination)
        let modeDuringExport = try #require(await exporter.modeDuringExport)
        let initialContents = try #require(await exporter.initialContents)
        let rootMode = try posixMode(root)

        #expect(header.contains("SAPISID="))
        #expect(initialContents == WebHomeCookieJarManager.netscapeCookieHeader)
        #expect(modeDuringExport & 0o777 == 0o600)
        #expect(rootMode & 0o777 == 0o700)
        #expect(!FileManager.default.fileExists(
            atPath: destination.deletingLastPathComponent().path))
    }

    @Test("old helper cookie workspaces are cleaned only inside the bounded root")
    func orphanCleanup() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let old = root.appendingPathComponent("old", isDirectory: true)
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: false)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-7_200)],
            ofItemAtPath: old.path)
        let outside = FileManager.default.temporaryDirectory
            .appendingPathComponent("muses-web-outside-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)

        _ = try WebHomeCookieJarManager(
            rootDirectory: root,
            exporter: RecordingCookieExporter(cookieText: cookieText))

        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: outside.path))
        try? FileManager.default.removeItem(at: outside)
    }

    @Test("export-only yt-dlp exit is accepted only after it writes cookie data")
    func exportOnlyProcessExitUsesValidatedJar() async throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("fake-yt-dlp")
        let script = """
        #!/bin/sh
        destination=""
        while [ "$#" -gt 0 ]; do
          if [ "$1" = "--cookies" ]; then
            shift
            destination="$1"
          fi
          shift
        done
        printf '.youtube.com\tTRUE\t/\tTRUE\t0\tSAPISID\tsecret\n' >> "$destination"
        exit 2
        """
        try Data(script.utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)

        let destination = root.appendingPathComponent("cookies.txt")
        try Data(WebHomeCookieJarManager.netscapeCookieHeader.utf8)
            .write(to: destination)
        let exporter = ProcessYTDlpCookieExporter(executableURL: executable)

        try await exporter.export(browserSpecification: "chrome", to: destination)

        let contents = try String(contentsOf: destination, encoding: .utf8)
        #expect(contents.contains("\tSAPISID\t"))

        try Data("#!/bin/sh\nexit 2\n".utf8).write(to: executable)
        #expect(chmod(executable.path, S_IRWXU) == 0)
        try Data(WebHomeCookieJarManager.netscapeCookieHeader.utf8)
            .write(to: destination)
        await expectCoreError(.cookieSourceUnavailable) {
            try await exporter.export(browserSpecification: "chrome", to: destination)
        }
    }

    @Test("an explicitly selected Netscape file is read without modification")
    func selectedFileIsReadOnly() async throws {
        let root = temporaryRoot()
        let source = root.deletingLastPathComponent()
            .appendingPathComponent("cookies-\(UUID().uuidString).txt")
        try Data(cookieText.utf8).write(to: source, options: .atomic)
        let before = try Data(contentsOf: source)
        let manager = try WebHomeCookieJarManager(
            rootDirectory: root,
            exporter: RecordingCookieExporter(cookieText: cookieText))

        _ = try await manager.withCookieJar(
            source: WebHomeCookieSourceDescriptor(filePath: source.path)) { jar in
                jar.sapisid
            }

        #expect(try Data(contentsOf: source) == before)
    }

    @Test("identity parser accepts only an explicit active or selected channel")
    func exactIdentityPaths() throws {
        let parser = WebHomeIdentityParser()
        let active = try JSONSerialization.data(withJSONObject: [
            "unrelated": ["browseId": "UC9999999999999999999999"],
            "actions": [[
                "popup": [
                    "activeAccountHeaderRenderer": ["channelId": channelID]
                ]
            ]]
        ])
        #expect(try parser.channelID(from: active) == channelID)

        let unrelatedOnly = try JSONSerialization.data(withJSONObject: [
            "contents": [["browseEndpoint": ["browseId": channelID]]]
        ])
        #expect(throws: WebHomeCoreError.code(.identityUnavailable)) {
            try parser.channelID(from: unrelatedOnly)
        }

        let currentAccountMenu = try JSONSerialization.data(withJSONObject: [
            "actions": [[
                "openPopupAction": [
                    "popup": [
                        "multiPageMenuRenderer": [
                            "header": ["activeAccountHeaderRenderer": [
                                "accountName": ["runs": [["text": "Account"]]]
                            ]],
                            "sections": [[
                                "multiPageMenuSectionRenderer": [
                                    "items": [[
                                        "compactLinkRenderer": [
                                            "navigationEndpoint": [
                                                "browseEndpoint": ["browseId": channelID]
                                            ]
                                        ]
                                    ]]
                                ]
                            ]]
                        ]
                    ]
                ]
            ]]
        ])
        #expect(try parser.channelID(from: currentAccountMenu) == channelID)

        let menuWithoutActiveHeader = try JSONSerialization.data(withJSONObject: [
            "multiPageMenuRenderer": [
                "sections": [["multiPageMenuSectionRenderer": ["items": [[
                    "compactLinkRenderer": ["navigationEndpoint": [
                        "browseEndpoint": ["browseId": channelID]
                    ]]
                ]]]]]
            ]
        ])
        #expect(throws: WebHomeCoreError.code(.identityUnavailable)) {
            try parser.channelID(from: menuWithoutActiveHeader)
        }
    }

    @Test("probe builds ephemeral authenticated requests and enforces exact OAuth match")
    func probeAndExactMatch() async throws {
        let transport = QueueWebHomeTransport(responses: [
            response(bootstrapHTML),
            response(identityJSON(channelID: channelID))
        ])
        let client = WebHomeSessionClient(
            transport: transport,
            now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let result = try await client.execute(
            request: request(expectedChannelID: channelID),
            cookies: cookieJar)

        #expect(result.channelID == channelID)
        #expect(result.payload == nil)
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "User-Agent")
            == WebHomeSessionClient.desktopWebUserAgent)
        #expect(requests[1].value(forHTTPHeaderField: "User-Agent")
            == WebHomeSessionClient.desktopWebUserAgent)
        #expect(requests[1].value(forHTTPHeaderField: "Authorization")?
            .hasPrefix("SAPISIDHASH 1700000000_") == true)
        #expect(requests[1].value(forHTTPHeaderField: "Cookie")?.contains("secret") == true)

        let mismatchTransport = QueueWebHomeTransport(responses: [
            response(bootstrapHTML),
            response(identityJSON(channelID: channelID))
        ])
        let mismatch = WebHomeSessionClient(transport: mismatchTransport)
        await expectCoreError(.accountMismatch) {
            try await mismatch.execute(
                request: request(expectedChannelID: "UC0000000000000000000000"),
                cookies: cookieJar)
        }
    }

    @Test("expired or incomplete cookie sessions fail without fetching Home")
    func missingSessionCookie() async {
        let transport = QueueWebHomeTransport(responses: [])
        let client = WebHomeSessionClient(transport: transport)
        let jar = WebHomeCookieJar(cookies: [WebHomeCookie(
            domain: ".youtube.com", path: "/", secure: true,
            expiresAt: nil, name: "SID", value: "not-sapisid")])

        await expectCoreError(.sessionExpired) {
            try await client.execute(
                request: request(expectedChannelID: channelID),
                cookies: jar)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test("Only unique authoritative identity candidates are accepted")
    func authoritativeIdentityUniqueness() throws {
        let parser = WebHomeIdentityParser()
        let wrongID = "UC9999999999999999999999"
        let header: [String: Any] = ["activeAccountHeaderRenderer": ["channelId": channelID]]
        let selected: [String: Any] = ["accountItemRenderer": ["isSelected": true, "channelId": channelID]]
        let unrelated: [String: Any] = ["recommendations": [["browseEndpoint": ["browseId": wrongID]]],
                                       "accountItemRenderer": ["isSelected": false, "channelId": wrongID]]
        let duplicate = try JSONSerialization.data(withJSONObject: [header, header, selected, unrelated])
        #expect(try parser.channelID(from: duplicate) == channelID)
        let conflicts: [[String: Any]] = [
            ["activeAccountHeaderRenderer": ["channelId": wrongID]],
            ["accountItemRenderer": ["isSelected": true, "channelId": wrongID]],
            ["activeAccountHeaderRenderer": ["channelId": channelID, "channelID": wrongID]]
        ]
        for conflict in conflicts {
            #expect(throws: WebHomeCoreError.code(.accountMismatch)) {
                try parser.channelID(from: JSONSerialization.data(withJSONObject: [header, conflict]))
            }
        }
        func currentMenu(linkIDs: [String], includeHeader: Bool = true) -> [String: Any] {
            let links: [[String: Any]] = linkIDs.map { id in
                ["compactLinkRenderer": ["navigationEndpoint": ["browseEndpoint": ["browseId": id]]]]
            }
            var menu: [String: Any] = [
                "sections": [["multiPageMenuSectionRenderer": ["items": links + [
                    ["videoRenderer": ["navigationEndpoint": ["browseEndpoint": ["browseId": wrongID]]]]
                ]]]],
                // A compact link outside the current-account section is not authority.
                "recommendations": [["compactLinkRenderer": ["navigationEndpoint": ["browseEndpoint": ["browseId": wrongID]]]]]
            ]
            if includeHeader { menu["header"] = header }
            return ["multiPageMenuRenderer": menu]
        }
        let repeatedCurrentLinks = try JSONSerialization.data(withJSONObject: currentMenu(linkIDs: [channelID, channelID]))
        #expect(try parser.channelID(from: repeatedCurrentLinks) == channelID)
        #expect(throws: WebHomeCoreError.code(.accountMismatch)) {
            try parser.channelID(from: JSONSerialization.data(withJSONObject: currentMenu(linkIDs: [wrongID])))
        }
        // An unrelated menu must not borrow an active header from elsewhere in the response.
        let unrelatedMenu = try JSONSerialization.data(withJSONObject: [header, currentMenu(linkIDs: [wrongID], includeHeader: false)])
        #expect(try parser.channelID(from: unrelatedMenu) == channelID)
    }

    @Test("Conflicting active identities fail before WEB fallback")
    func conflictingIdentityStopsFallback() async throws {
        let conflicting = try JSONSerialization.data(withJSONObject: [
            ["activeAccountHeaderRenderer": ["channelId": channelID]],
            ["accountItemRenderer": ["isSelected": true, "channelId": "UC9999999999999999999999"]]
        ])
        let transport = QueueWebHomeTransport(responses: [response(bootstrapHTML), response(conflicting)])
        await expectCoreError(.accountMismatch) {
            try await WebHomeSessionClient(transport: transport).execute(
                request: request(expectedChannelID: channelID), cookies: cookieJar)
        }
        #expect(await transport.requests.count == 2)
    }

    @Test("Middle-dot handles resolve read-only and still require the exact OAuth channel")
    func middleDotHandleResolution() async throws {
        let handle = "@foo·bar"
        let accounts = try JSONSerialization.data(withJSONObject: [
            "accountItem": ["isSelected": true, "channelHandle": ["runs": [["text": handle]]]]
        ])
        #expect(try WebHomeIdentityParser().selectedHandle(from: accounts) == handle)
        let resolved = try JSONSerialization.data(withJSONObject: ["endpoint": ["browseEndpoint": ["browseId": channelID]]])
        let web = WebHomeTransportResponse(data: bootstrapHTML, statusCode: 200,
                                          finalURL: URL(string: "https://www.youtube.com/"))
        for expectedID in [channelID, "UC9999999999999999999999"] {
            let empty = response(Data("{}".utf8))
            let transport = QueueWebHomeTransport(responses: [response(bootstrapHTML), empty, web, empty,
                                                             response(accounts), response(resolved)])
            let client = WebHomeSessionClient(transport: transport)
            if expectedID == channelID {
                let result = try await client.execute(request: request(expectedChannelID: expectedID), cookies: cookieJar)
                #expect(result.channelID == channelID)
                #expect(result.payload == nil)
            } else {
                await expectCoreError(.accountMismatch) {
                    try await client.execute(request: request(expectedChannelID: expectedID), cookies: cookieJar)
                }
            }
            let requests = await transport.requests
            #expect(requests.count == 6)
            let resolveRequest = try #require(requests.last)
            #expect(resolveRequest.url?.path == "/youtubei/v1/navigation/resolve_url")
            let body = try #require(resolveRequest.httpBody)
            let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let resolvedURL = try #require(object["url"] as? String)
            let components = try #require(URLComponents(string: resolvedURL))
            #expect(components.scheme == "https")
            #expect(components.host == "www.youtube.com")
            #expect(components.path == "/" + handle)
        }
    }

    @Test("WEB identity fallback verifies the same account without fetching Home")
    func identityFallback() async throws {
        let web = WebHomeTransportResponse(data: bootstrapHTML, statusCode: 200,
                                          finalURL: URL(string: "https://www.youtube.com/"))
        let transport = QueueWebHomeTransport(responses: [response(bootstrapHTML), response(Data("{}".utf8)),
                                                         web, response(identityJSON(channelID: channelID))])
        let result = try await WebHomeSessionClient(transport: transport).execute(
            request: request(expectedChannelID: channelID), cookies: cookieJar)
        #expect(result.channelID == channelID)
        #expect(result.payload == nil)
        let requests = await transport.requests
        #expect(requests.count == 4)
        #expect(requests[3].url?.host == "www.youtube.com")
        #expect(requests[3].value(forHTTPHeaderField: "X-YouTube-Client-Name") == "1")
        #expect(requests[3].value(forHTTPHeaderField: "Origin") == "https://www.youtube.com")
    }

    @Test("Bootstrap ignores incidental consent scripts but rejects visible challenges")
    func bootstrapChallenges() throws {
        let parser = WebHomeBootstrapParser()
        let normal = Data((String(decoding: bootstrapHTML, as: UTF8.self)
            + "<script src='https://www.google.com/recaptcha/api.js'></script><a href='https://consent.youtube.com'>Privacy</a>").utf8)
        #expect(try parser.parse(html: normal, locale: "en", region: "US").apiKey == "key")
        let challenge = Data("<form action='https://consent.youtube.com/save'>Continue</form>".utf8)
        #expect(throws: WebHomeCoreError.code(.consentOrCaptchaRequired)) {
            try parser.parse(html: challenge, locale: "en", region: "US")
        }
    }

    @Test("WEB identity fallback rejects a changed selected account")
    func fallbackAccountSwitch() async throws {
        let selected = Data("""
        {"INNERTUBE_API_KEY":"key","INNERTUBE_CLIENT_VERSION":"1","VISITOR_DATA":"visitor","SESSION_INDEX":1}
        """.utf8)
        let web = WebHomeTransportResponse(data: selected, statusCode: 200,
                                          finalURL: URL(string: "https://www.youtube.com/"))
        let transport = QueueWebHomeTransport(responses: [response(bootstrapHTML), response(Data("{}".utf8)), web])
        await expectCoreError(.accountMismatch) {
            try await WebHomeSessionClient(transport: transport).execute(
                request: request(expectedChannelID: channelID), cookies: cookieJar)
        }
        #expect(await transport.requests.count == 3)
    }

    private var cookieText: String {
        "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t0\tSAPISID\tsecret\n"
    }

    private var cookieJar: WebHomeCookieJar {
        WebHomeCookieJar(cookies: [WebHomeCookie(
            domain: ".youtube.com", path: "/", secure: true,
            expiresAt: nil, name: "SAPISID", value: "secret")])
    }

    private var bootstrapHTML: Data {
        Data("""
        <html><script>window.ytcfg={"INNERTUBE_API_KEY":"key",
        "INNERTUBE_CLIENT_VERSION":"1.20260829.00.00",
        "VISITOR_DATA":"visitor"};</script></html>
        """.utf8)
    }

    private func identityJSON(channelID: String) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "actions": [[
                "openPopupAction": [
                    "popup": [
                        "activeAccountHeaderRenderer": ["channelId": channelID]
                    ]
                ]
            ]]
        ])
    }

    private func response(_ data: Data, status: Int = 200) -> WebHomeTransportResponse {
        WebHomeTransportResponse(
            data: data, statusCode: status,
            finalURL: URL(string: "https://music.youtube.com/"))
    }

    private func request(expectedChannelID: String) -> WebHomeRequest {
        WebHomeRequest(
            action: .probeSession,
            expectedChannelID: expectedChannelID,
            cookieSource: WebHomeCookieSourceDescriptor(browserName: "safari"),
            locale: "en-US",
            region: "US")
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("muses-web-cookie-test-\(UUID().uuidString)", isDirectory: true)
    }

    private func posixMode(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try #require(attributes[.posixPermissions] as? Int)
    }

    private func expectCoreError<T: Sendable>(
        _ code: WebHomeErrorCode,
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            Issue.record("Expected \(code.rawValue)")
        } catch is WebHomeCookieFailure {
            #expect(code == .cookieSourceUnavailable)
        } catch let error as WebHomeIdentityFailure {
            #expect(error.code == code)
        } catch let error as WebHomeCoreError {
            #expect(error == .code(code))
        } catch {
            Issue.record("Unexpected error: \(type(of: error))")
        }
    }
}

private struct StageCookieExporter: YTDlpCookieExporting {
    let stage: WebHomeCookieFailureStage
    func export(browserSpecification: String, to destination: URL) async throws -> WebHomeCookieFailureStage? {
        switch stage {
        case .jarRead: try Data([0xff]).write(to: destination)
        case .noAllowedDomain: try Data(WebHomeCookieJarManager.netscapeCookieHeader.utf8).write(to: destination)
        default: throw WebHomeCookieFailure(stage: stage)
        }
        return nil
    }
}

private actor RecordingCookieExporter: YTDlpCookieExporting {
    let cookieText: String
    private(set) var destination: URL?
    private(set) var modeDuringExport: Int?
    private(set) var initialContents: String?

    init(cookieText: String) {
        self.cookieText = cookieText
    }

    func export(browserSpecification: String, to destination: URL) async throws -> WebHomeCookieFailureStage? {
        self.destination = destination
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        modeDuringExport = attributes[.posixPermissions] as? Int
        initialContents = try String(contentsOf: destination, encoding: .utf8)
        try Data(cookieText.utf8).write(to: destination)
        return nil
    }
}

private actor QueueWebHomeTransport: WebHomeTransport {
    private var responses: [WebHomeTransportResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [WebHomeTransportResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> WebHomeTransportResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
        return responses.removeFirst()
    }
}
