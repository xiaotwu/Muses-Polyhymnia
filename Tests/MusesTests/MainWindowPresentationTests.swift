import Testing
@testable import Muses

@Suite("Main-window presentation readiness") @MainActor
struct MainWindowPresentationTests {
    @Test("a cold request survives until a late scene factory and actual window attachment")
    func lateFactory() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        var presentations = 0

        #expect(!coordinator.request(presentExisting: { false }))
        #expect(coordinator.isPending)
        #expect(!coordinator.isCreationRequested)
        coordinator.installFactory { creations += 1 }
        // Registration does not open a scene during Commands.body evaluation.
        #expect(creations == 0)
        #expect(coordinator.fulfillPendingRequest(presentExisting: { false }))
        #expect(creations == 1)
        #expect(coordinator.isPending)
        #expect(coordinator.isCreationRequested)

        coordinator.mainWindowConfigured { presentations += 1 }
        #expect(presentations == 1)
        #expect(!coordinator.isPending)
        #expect(!coordinator.isCreationRequested)
    }

    @Test("repeated early requests and command refreshes create one window")
    func coalescedBootstrap() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        for _ in 0..<3 { #expect(!coordinator.request(presentExisting: { false })) }
        coordinator.installFactory { creations += 1 }
        #expect(coordinator.fulfillPendingRequest(presentExisting: { false }))
        for _ in 0..<3 {
            coordinator.installFactory { creations += 1 }
            #expect(coordinator.request(presentExisting: { false }))
            #expect(coordinator.fulfillPendingRequest(presentExisting: { false }))
        }
        #expect(creations == 1)
        #expect(coordinator.isPending)
        coordinator.mainWindowConfigured {}
        #expect(!coordinator.fulfillPendingRequest(presentExisting: { false }))
        #expect(creations == 1)
    }

    @Test("an existing main window satisfies the request without creating another")
    func existingWindow() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        var presentations = 0
        coordinator.installFactory { creations += 1 }
        #expect(coordinator.request(presentExisting: { presentations += 1; return true }))
        #expect(presentations == 1)
        #expect(creations == 0)
        #expect(!coordinator.isPending)
        #expect(!coordinator.isCreationRequested)
    }

    @Test("a manually attached window cancels a deferred bootstrap")
    func attachmentBeforeFactoryReadiness() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        var presentations = 0
        #expect(!coordinator.request(presentExisting: { false }))
        coordinator.mainWindowConfigured { presentations += 1 }
        coordinator.installFactory { creations += 1 }
        #expect(!coordinator.fulfillPendingRequest(presentExisting: { false }))
        #expect(presentations == 1)
        #expect(creations == 0)
        coordinator.mainWindowConfigured { presentations += 1 }
        #expect(presentations == 1)
    }

    @Test("closing an acknowledged window permits a later request to create one replacement")
    func recreationAfterClose() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        coordinator.installFactory { creations += 1 }
        #expect(coordinator.request(presentExisting: { false }))
        coordinator.mainWindowConfigured {}
        #expect(coordinator.request(presentExisting: { false }))
        #expect(coordinator.request(presentExisting: { false }))
        #expect(creations == 2)
        coordinator.mainWindowConfigured {}
        #expect(!coordinator.isPending)
    }

    @Test("a synchronous factory attachment safely acknowledges its own request")
    func synchronousAttachment() {
        let coordinator = MainWindowPresentationCoordinator()
        var presentations = 0
        coordinator.installFactory {
            coordinator.mainWindowConfigured { presentations += 1 }
        }
        #expect(coordinator.request(presentExisting: { false }))
        #expect(presentations == 1)
        #expect(!coordinator.isPending)
        #expect(!coordinator.isCreationRequested)
    }

    @Test("factory installation without a business request preserves a windowless process")
    func noImplicitWindow() {
        let coordinator = MainWindowPresentationCoordinator()
        var creations = 0
        coordinator.installFactory { creations += 1 }
        #expect(!coordinator.fulfillPendingRequest(presentExisting: { false }))
        #expect(creations == 0)
        #expect(!coordinator.isPending)
    }
}
