import Foundation
import SwiftData

/// Preset edits use a separate transaction so a failed save cannot leave a
/// pending insert/delete in the UI context or commit another editor's draft.
@MainActor
struct EQPresetStore {
    enum StoreError: Error { case emptyName, missingPreset }

    let container: ModelContainer
    var saveContext: (ModelContext) throws -> Void = { try $0.save() }

    func save(name: String, bands: [EQBand]) throws -> UUID {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StoreError.emptyName }
        let context = editingContext()
        let preset = EQPreset(name: name, bandsJSON: EQPreset.encode(bands))
        context.insert(preset)
        do {
            try saveContext(context)
            return preset.id
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        let context = editingContext()
        do {
            guard let preset = try context.fetch(FetchDescriptor<EQPreset>(
                predicate: #Predicate { $0.id == id }
            )).first else { throw StoreError.missingPreset }
            context.delete(preset)
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func editingContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
