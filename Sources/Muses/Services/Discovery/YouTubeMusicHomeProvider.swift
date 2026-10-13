import Foundation

/// Account Home has one source: the explicitly consented, isolated Web helper.
/// No anonymous request or fallback is made when that capability is unavailable.
@MainActor
final class YouTubeMusicHomeProvider: HomeDiscoveryProvider {
    private let authenticated: HomeDiscoveryProvider?

    init(authenticated: HomeDiscoveryProvider?) {
        self.authenticated = authenticated
    }

    var hasWebEnhancement: Bool { authenticated?.hasWebEnhancement == true }
    var hasGlobalContinuation: Bool {
        hasWebEnhancement && authenticated?.hasGlobalContinuation == true
    }
    var needsLiveRefreshForContinuations: Bool {
        hasWebEnhancement && authenticated?.needsLiveRefreshForContinuations == true
    }
    func resetContinuations() { authenticated?.resetContinuations() }
    func hasContinuation(for sectionID: String) -> Bool {
        hasWebEnhancement && authenticated?.hasContinuation(for: sectionID) == true
    }

    func fetch(for input: HomeDiscoveryInput) async -> HomeFetchResult {
        let empty = HomeFetchResult.baseline(scope: input.scope, sections: []).baselineSnapshot
        guard case .account(let channelID) = input.scope else {
            return result(baseline: empty, capability: .signedOut)
        }
        guard let authenticated, authenticated.hasWebEnhancement else {
            return result(baseline: empty, capability: .notConfigured)
        }

        PerfTrace.event("home.mode.youtubeMusic")
        let fetched = await authenticated.fetch(for: input)
        guard !Task.isCancelled, authenticated.hasWebEnhancement else {
            return result(baseline: empty, capability: .notConfigured)
        }
        let failures = fetched.failures.filter { $0.layer == .web }
        guard failures.isEmpty, let snapshot = fetched.webSnapshot else {
            let capability: HomeWebCapability
            if case .available = fetched.webCapability {
                capability = .unavailable(reason: nil)
            } else {
                capability = fetched.webCapability
            }
            return result(baseline: empty, capability: capability, failures: failures)
        }
        guard snapshot.belongs(to: input.scope), snapshot.source == .signedInWeb,
              !snapshot.sections.isEmpty,
              snapshot.sections.allSatisfy({
                  $0.source == .signedInWeb && $0.accountChannelID == channelID
                      && $0.schemaVersion > 0 && $0.status == .loaded
              }) else {
            let message = tr("Personalized Home data did not match the active account or schema.",
                             "个性化首页数据与当前账号或架构不匹配。")
            return result(baseline: empty, capability: .rejected(reason: message), failures: [
                HomeFetchFailure(layer: .web, code: .shapeChanged, message: message)
            ])
        }
        return HomeFetchResult(
            baselineSnapshot: empty, webSnapshot: snapshot,
            webCapability: .available(accountChannelID: channelID), failures: [],
            cacheDirectives: HomeCacheDirectives(
                storeBaseline: false, storeWeb: fetched.cacheDirectives.storeWeb))
    }

    func more(page: Int, input: HomeDiscoveryInput) async -> [HomeSection] {
        guard case .account(let channelID) = input.scope,
              let authenticated, authenticated.hasWebEnhancement else { return [] }
        let sections = await authenticated.more(page: page, input: input)
        guard !Task.isCancelled, authenticated.hasWebEnhancement,
              sections.allSatisfy({
                  $0.source == .signedInWeb && $0.accountChannelID == channelID
                      && $0.schemaVersion > 0 && $0.status == .loaded
              }) else { return [] }
        return sections
    }

    func more(sectionID: String, input: HomeDiscoveryInput) async -> [DiscoveryItem] {
        guard case .account = input.scope,
              let authenticated, authenticated.hasWebEnhancement else { return [] }
        let items = await authenticated.more(sectionID: sectionID, input: input)
        guard !Task.isCancelled, authenticated.hasWebEnhancement else { return [] }
        return items
    }

    private func result(baseline: HomeSnapshot, capability: HomeWebCapability,
                        failures: [HomeFetchFailure] = []) -> HomeFetchResult {
        HomeFetchResult(baselineSnapshot: baseline, webSnapshot: nil,
                        webCapability: capability, failures: failures,
                        cacheDirectives: .preserveAll)
    }
}
