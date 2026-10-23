# Interrupted catalog detail recovery — October 23, 2026

[XW-119](https://linear.app/xiaotwu/issue/XW-119), under [XW-73](https://linear.app/xiaotwu/issue/XW-73), fixes a remaining Search re-entry gap. Leaving Search cancels the current catalog request. A selected album, artist or podcast detail previously prevented re-entry from restarting its interrupted first page. If supplemental search was still running, its retry instead started a new catalog search and cleared the detail/category.

`MusicCatalogBrowser.resumeIfNeeded()` now resumes only an unfinished first page of the existing presentation. Loaded pages, cursor, metadata, navigation history and explicit failure/Retry remain intact. Search re-entry handles saved detail with an empty query. Supplemental retry resumes the existing catalog rather than replacing it; request identity and cancellation still reject obsolete responses.

## Controlled regression

The new existing-API supplemental-retry regression compiled on the old `168b42a` source and failed eight assertions: selected detail/category, rows/metadata, failed-page state and subsequent cursor recovery were lost. The supplementary-page timing variant remained a passing control. The five affected search/catalog files were identical between that source and this branch's `6df36ba` main baseline before this patch.

After repair, all 26 `GlobalSearchStateTests` and `MusicCatalogBrowserTests` passed. Four new test definitions/six parameter cases cover normal and saved-browse initial cancellation, obsolete response rejection, loaded detail retention, first-page failure requiring explicit Retry, and supplemental initial/continuation cancellation while preserving a failed detail cursor. Independent source review found no further defect in these paths.

## Bounded native check

A fresh isolated candidate `com.muses.acceptance.remaining-oct23`, build `20261023.1191`, used the PR #17 development packaging/backend plus this catalog patch. All three changed catalog implementation files have recorded hashes equal to this branch; the whole candidate is not represented as a standalone main-branch release artifact.

Real Roselia search loaded the public catalog. Opening Lehre der Rose, going Home and returning retained the same visible album and Roselia query; another loaded-detail Home/Back round trip retained them. Stable inspected pixels showed its title, artist and actual initial tracks. The exact first-request interruption timing was not proven by native observation, so the held-provider tests supply that specific regression evidence. No forced network failure, error/Retry, complete row/tail audit, paging or VoiceOver claim is added.

Some AX snapshots retained old search rows while the painted view displayed the album. One subsequent See all Albums lookup consequently failed without an input; it is retained as a tool observation, not an application defect. Acceptance uses the inspected stable pixels rather than the stale tree.

The candidate quit normally, its PID is absent, and the fresh store retains zero Tracks and zero listening events. There were no Play, import, subscription or account inputs. The namespace, candidate, raw observations and test logs remain stopped under `~/.muses/tmp/engineering-oct15/remaining-repairs-oct23-01a16186/`.

Formal application/data/preferences, prior packaging output and three existing evidence roots matched the execution baseline. An unrelated owned command-directory mistake during this same session altered generated shared build cache; its explicit exception and retained delta are documented in the private handoff and the PR #17 development-bundle report. No original-cache preservation claim is made.

XW-73 remains In Review for its separate consented identity-matched Web Home, remaining genuine source/error/account and platform/accessibility cells. XW-119 is submitted for review; exact standalone branch CI is tracked separately. Premium deferred, XW-74 paused and the 0.6.2 release hold remain unchanged.
