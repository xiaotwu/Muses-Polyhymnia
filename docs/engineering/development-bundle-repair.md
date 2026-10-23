# Development bundle repair — October 23, 2026

[XW-118](https://linear.app/xiaotwu/issue/XW-118) follows the development-entrypoint review of [PR #17](https://github.com/xiaotwu/Muses-Polyhymnia/pull/17). The existing production packaging path already signs nested dependencies individually. The old development runner instead reused an arbitrary app, copied selected resources and recursively applied the main application's entitlements. A pre-refactor app could retain its old root resolver or lack libmpv/Deno. Its validation identity also fell outside the acceptance namespace, and process-name termination could stop an unrelated installed application.

## Confirmed failure and repair

A fresh task-owned clone of the successful `168b42a` CI preview ran Deno 2.9.7 `eval` successfully. Applying the old development signing command replaced Deno's `allow-jit` entitlement with the main application entitlements; the same command then exited with SIGTRAP (-5). Both resolver receipts still passed in that control. The observed signature failure is Deno-specific, rather than evidence that every resolver signature was changed.

Every development mode now assembles a complete Debug bundle through `build-app.sh`. Release remains the default for that packager. Development and validation use distinct `com.muses.acceptance.*` identifiers and output paths. Packaging disables their update and account configuration, and the runner clears OAuth environment overrides before launching a debugger. Deno, resolver runtimes, audio libraries and Sparkle retain their separate signing contracts.

`--verify` builds and verifies without launching the GUI. The packager validates the prepared audio dependency and matching App Intents metadata before changing inputs or output. It rejects `/Applications` output, including a parent symlink, before replacement. An executable-path check rejects a running output application or nested helper; it never terminates another process. Logs and telemetry select the exact candidate executable. Setup instructions are in [Complete development bundles](development-builds.md).

## Validation

- 12 executable-fixture development regressions cover complete-packager delegation, stale-output replacement, no launch/kill during verification, separate identities, debug OAuth environment removal, exact log predicates and failure before mutation. Four additional audio-dependency cases exercise read-only validation, missing/changed libraries, source/notices and escaping aliases. All 50 release/configuration tests passed with Python 3.14; CI uses Python 3.12.
- A fresh private SwiftPM/Xcode tree passed 1,081 Swift tests in 146 suites. This local integration tree also contained the separately submitted XW-119 search repair; its four new test definitions account for the increase from 1,077. Seven strict cooperative-worker tests and the separately enabled real disk-recovery test passed. Exact PR-head CI remains a separate check.
- The actual development entrypoint replaced a stale output marker with a complete Debug app. A compiled task-owned sleeping helper inside another output app caused the real packager to refuse replacement while retaining its marker. After that helper exited, verification completed without GUI launch.
- Actual packaged Deno execution, both complete resolver receipts/version executions, libmpv dependency closure, App Intents metadata and deep/strict outer signatures passed. The derived isolated native candidate retained Deno's narrow JIT entitlement. This is ad-hoc development validation, not Developer ID, notarization or release acceptance.

The first Python run used the system's unsupported 3.9 interpreter and failed in the existing `hashlib.file_digest` dependency helper. The supported-interpreter rerun passed. Raw failures and corrected controls remain in the private evidence directory.

## Preservation and remaining gates

Formal application, normal data/preferences, existing packaging output and three prior evidence roots matched the new baseline: seven protected roots remained identical. One owned regression command was mistakenly started in the canonical checkout before being interrupted. It changed 1,858 generated `.build` nodes; the baseline, complete delta and 1,830 current changed files were retained. Original generated-cache bytes were not restored. Subsequent checks froze this explicit exception and verified no further changes; no preservation claim is made for the original shared cache.

All further builds used a new private source/build root. Native work used a fresh acceptance namespace, normal Quit, zero remaining candidate processes and no playback/import/account inputs. The candidate and evidence remain stopped. Evidence is under `~/.muses/tmp/engineering-oct15/remaining-repairs-oct23-01a16186/`.

PR #17 remains Draft and 0.6.2 remains held for integration, the final Developer ID/notarized artifact and applicable native playback gates. XW-107's earlier cold-media evidence is preserved; these development checks do not repeat or expand it. Premium remains deferred and XW-74 remains paused.
