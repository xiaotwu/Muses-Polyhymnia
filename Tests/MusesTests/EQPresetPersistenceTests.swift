import Foundation
import SwiftData
import Testing
@testable import Muses

@MainActor
@Suite("EQ preset persistence")
struct EQPresetPersistenceTests {
    private enum SaveError: Error { case injected }

    private struct StoredPreset: Equatable {
        let id: UUID
        let name: String
        let bandsJSON: String
        let createdAt: Date
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: EQPreset.self,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func storedPresets(_ container: ModelContainer) throws -> [StoredPreset] {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try context.fetch(FetchDescriptor<EQPreset>()).map {
            StoredPreset(id: $0.id, name: $0.name, bandsJSON: $0.bandsJSON, createdAt: $0.createdAt)
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    @Test("failed creation rolls back without losing a retry or other saved presets")
    func failedCreateCanRetry() throws {
        let container = try makeContainer()
        let existingID = try EQPresetStore(container: container).save(name: "Existing", bands: EQPresets.flat)
        let before = try storedPresets(container)
        var shouldFail = true
        var failedContext: ModelContext?
        let store = EQPresetStore(container: container, saveContext: { context in
            if shouldFail { failedContext = context; throw SaveError.injected }
            try context.save()
        })
        var bands = EQPresets.flat
        bands[3].gain = 5

        #expect(throws: SaveError.self) { try store.save(name: "  Draft  ", bands: bands) }
        #expect(failedContext?.hasChanges == false)
        #expect(try storedPresets(container) == before)

        shouldFail = false
        let savedID = try store.save(name: "  Draft  ", bands: bands)
        let after = try storedPresets(container)
        #expect(after.count == 2)
        #expect(after.first { $0.id == existingID } == before.first)
        #expect(after.first { $0.id == savedID }?.name == "Draft")
        let savedJSON = try #require(after.first { $0.id == savedID }?.bandsJSON)
        #expect(try JSONDecoder().decode([EQBand].self, from: Data(savedJSON.utf8)) == bands)
    }

    @Test("failed deletion preserves the exact saved row and can retry by identity")
    func failedDeleteCanRetry() throws {
        let container = try makeContainer()
        let initialStore = EQPresetStore(container: container)
        let removedID = try initialStore.save(name: "Remove", bands: BuiltinEQPresets.bassBoost())
        let keptID = try initialStore.save(name: "Keep", bands: EQPresets.flat)
        let before = try storedPresets(container)
        var shouldFail = true
        var failedContext: ModelContext?
        let store = EQPresetStore(container: container, saveContext: { context in
            if shouldFail { failedContext = context; throw SaveError.injected }
            try context.save()
        })

        #expect(throws: SaveError.self) { try store.delete(id: removedID) }
        #expect(failedContext?.hasChanges == false)
        #expect(try storedPresets(container) == before)

        shouldFail = false
        try store.delete(id: removedID)
        #expect(try storedPresets(container) == before.filter { $0.id == keptID })
    }

    @Test("preset transactions neither commit nor roll back an unrelated UI draft")
    func preservesUnrelatedPendingEdits() throws {
        let container = try makeContainer()
        let store = EQPresetStore(container: container)
        let existingID = try store.save(name: "Saved", bands: EQPresets.flat)
        let uiContext = container.mainContext
        uiContext.autosaveEnabled = false
        let draft = try #require(uiContext.fetch(FetchDescriptor<EQPreset>()).first)
        draft.name = "Unsaved edit"
        let before = try storedPresets(container)
        let failing = EQPresetStore(container: container, saveContext: { _ in throw SaveError.injected })

        #expect(throws: SaveError.self) { try failing.save(name: "New", bands: EQPresets.flat) }
        #expect(throws: SaveError.self) { try failing.delete(id: existingID) }
        let savedID = try store.save(name: "New", bands: EQPresets.flat)
        try store.delete(id: savedID)

        #expect(draft.name == "Unsaved edit")
        #expect(uiContext.hasChanges)
        #expect(try storedPresets(container) == before)
        uiContext.rollback()
    }

    @Test("empty names and stale deletion identities do not commit a transaction")
    func invalidEditsDoNotSave() throws {
        let container = try makeContainer()
        var saves = 0
        let store = EQPresetStore(container: container, saveContext: { context in
            saves += 1
            try context.save()
        })
        #expect(throws: EQPresetStore.StoreError.self) {
            try store.save(name: " \n ", bands: EQPresets.flat)
        }
        #expect(throws: EQPresetStore.StoreError.self) { try store.delete(id: UUID()) }
        #expect(saves == 0)
        #expect(try storedPresets(container).isEmpty)
    }
}
