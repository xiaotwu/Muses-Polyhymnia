# Muses approved UI/UX implementation plan

This is the active implementation contract for the user's completed selections, not a new round of ideation. Raw choices are in `ui-ux-selected-choices.json`; the latest full export with the approved hero combination is `ui-ux-selected-hero-choices.json`. Explicit typed decisions supersede old audit recommendations and conflicting visual guardrails.

## Completion accounting

Concept samples and imported choices are complete. The selected production reconstruction is implemented across the areas accounted for below; comprehensive acceptance remains open. Implementation, test/package validation and live-state acceptance are separate milestones. Foundation commit `c1c9dcb` raised the macOS floor and repaired a subset of settings controls. Hero commit `a2e8a6e` implemented H0 structure + H2 center emphasis + H3 optional information. No other area may be marked complete merely because an SVG exists or a unit test passes.

Per-area completion requires production code, proportionate build/tests, rendered runtime evidence, keyboard/pointer/context-menu/focus checks and relevant state/accessibility checks. Record evidence and gaps in its Linear task. Final completion requires reconciliation of all 64 areas; an unverified state remains pending. macOS below 26 is out of scope. Keep existing user data, queue semantics and shared services intact.

### Historical: phase 1 first implementation — 2026-10-01

Persistent native glass navigation islands now replace the expandable playlist sidebar. Search/Home and library destinations form separate capsules, with an independent Settings circle. Settings uses two category islands including the approved shortcuts category. Hover expands labels over content without changing its width. Albums/Artists share a native menu. Immersive playback reveals the same navigation on pointer entry and fades it on exit; a view focus callback supports keyboard reveal.

Verification: all 765 tests in 106 suites passed; the release acceptance bundle built and signed successfully. Rendered native inspection confirmed Settings hover expansion, separate catalog menu navigation, Settings PlayerBar hiding and browsing restoration, immersive pointer reveal/fade, and toolbar Back closing immersive playback. Playback remained paused at the same position. Private screenshots remain in the local acceptance directory and are not uploaded to Linear.

Remaining phase 1 acceptance: compact windows, full keyboard traversal/focus reveal, VoiceOver naming (including the native catalog menu), light/high-contrast/Reduce Transparency, and the approved shared typography/content-width treatment. This increment does not complete XW-7 or all 64 areas.

### Historical: phase 1 typography and phase 2 first implementation — 2026-10-01

Shared browsing/settings titles now use native SF typography at a consistent 28pt; shared section headings use 20pt. Expressive editorial, hero, song-information and lyric font families remain available. Navigation hover covers the expanded label width. The catalog menu's label now has an explicit accessibility boundary; its semantic name survived repeated runtime state changes in the isolated acceptance instance.

The existing full-height trailing queue now prioritizes a current-song summary, manual Up Next, current collection and optional groups/history. Sections have counts and native disclosure actions; history starts collapsed. Empty sections explain their next action. Native track menus add boundary-checked Move Up/Down through the existing queue service, while drag ordering, groups, locks, restoration and confirmation semantics remain intact. Smart Shuffle has a native explanation popover; Escape dismisses it before closing the queue.

History now has quiet metric summaries, an adaptive range header, an optional heatmap and timestamped listening rows with independent listened-duration/completion values and full track context menus. Completion comes from stored events through an immutable snapshot; unknown remains unknown. No persistence schema or playback engine changed.

Verification: all 766 tests in 106 suites passed after the interaction fixes, including a new stored/unknown completion test. The first signed release bundle passed rendered native inspection of full-height queue composition, 514-item collection disclosure, five-item history disclosure, empty Up Next, the Smart Shuffle explanation, collapsed/expanded history heatmap, its data-table alternative, and unknown completion labels. Playback remained paused at 0:08. Screenshots remain private under `~/.muses/acceptance/queue-history-20261001`.

Additional isolated native verification confirmed idle transport disabling, actionable queue/volume, all empty queue sections, stable catalog menu naming, and the complete Escape sequence: first dismiss the explanation and restore queue focus, then close the queue. Focus returns after the native popover dismissal so the same exit event cannot reach the parent. Group disclosure targets are now 28pt. The final focus repair passed a debug build and rendered interaction inspection. A production review relaunch waited in Keychain access; isolated acceptance used the existing separate credential/data/cache namespace without changing access permissions.

Remaining: compact/light/accessibility matrices; full keyboard traversal, queue menu/reorder/group mutations and clear/replay recovery in an isolated acceptance store. These areas remain In Progress, not complete. Native queue rows currently expose their menu label as the row name in AX, although the track identity is present in the value; include this in XW-12 acceptance.

### Historical: phase 3 overview and filter increment — 2026-10-01

All Playlists now defaults to a lazy native list with an optional adaptive square cover grid. Layout choice persists through relaunch. Titles/owner/count sit outside artwork; one source/status mark carries sync detail, with visible review warnings. Open, Play and the per-playlist options menu are separate native controls. Existing pin/delete/undo, import synchronization, versions, sharing, video and recently-deleted flows retain their service calls. Empty collection Play is disabled. The approved detail hero remains unchanged.

Search source is now a native menu beside a separately named YouTube Music category menu. The existing category provider and main-window history remain authoritative; the remote category is disabled for Library scope or an empty query. The duplicate category picker inside remote results was removed. Editorial cards now expose separate Open/Play accessibility actions, and keyboard focus keeps the Play affordance visible.

Validation: 765 tests in 106 suites passed; the signed final release package passed app/helper signature checks and both bundled yt-dlp launches. One obsolete test enforcing the superseded 260×330 overview hero-card dimensions was removed together with its unused metrics. This does not alter the H0/H2/H3 detail hero guardrails. Populated rendered acceptance used a read-only SQLite backup into the existing isolated acceptance namespace, with separate credentials and preferences. Native inspection confirmed default list, square grid, relaunch persistence, per-playlist menu naming after menu dismissal, disabled empty Play, preserved sync/version/share/delete menu entries, detail hero/navigation, and Library search/empty-result state. A disposable local Muses playlist was created only in that copy to inspect its source/empty branch. Screenshots remain local under `~/.muses/acceptance/discovery-20261001`.

Remaining phase 3 work: Home source/recovery menu and content-type artwork; New provenance and shared shelves; broader catalog/video/favorites states; Spotlight quick entry; grouped-result expansion and catalog details; podcast continuation and subscription/Shorts segmentation; reduced hero stage/table/cover-wall/detail heading acceptance. Remote category execution, editorial keyboard traversal, compact/light/high-contrast/Reduce Transparency and actual VoiceOver remain unverified. XW-8/XW-9 remain In Progress.

### Integrated implementation delivery — 2026-10-02

The approved reconstruction now has production implementations for the navigation/chrome, discovery/catalog/search, preserved H0 + H2 + H3 collection hero, playlist operations, queue/history, playback/lyrics/auxiliary surfaces and settings combinations recorded below. Implementation commit `782f633` delivers the reconstructed surfaces; `6df4cf2` repairs two rendered layout defects. The integrated suite passed **774 tests in 106 suites**; final targeted chrome/collection verification passed **72 tests in 2 suites**, and ad-hoc signed release packaging passed again. These checks establish build and behavioral guardrails; they do not establish comprehensive rendered or authenticated acceptance. Earlier phase paragraphs are historical snapshots; their “remaining” lists describe those earlier increments and are superseded by the current area table and [acceptance ledger](ui-ux-redesign-acceptance.md).

Latest native inspection verified the entire navigation island group centered as one group with equal 16pt gaps, including its footer action. Home, Queue and Now Playing were inspected with Reduce Transparency; Now Playing's empty-lyrics recovery was inspected with Increase Contrast. Earlier isolated native inspections covered the playlist list/grid and persisted choice, source/search menus, gallery preview, integrated queue/history and auxiliary/settings surfaces. Native Reduce Motion inspection exercised the deck and vinyl. Reduce Motion, Reduce Transparency and Increase Contrast were restored to their original off values; a fresh NSWorkspace read confirmed all three false. VoiceOver remained enabled. Private screenshots and acceptance-store content remain local and are not committed.

Live authenticated catalog/podcast/channel results, actual browser consent/cookie recovery, notification/media permission transitions, remote playlist/subscription writes and eligible update download/installation were not exercised end to end. The dedicated consent and exact-target confirmation boundaries remain required. The complete keyboard/VoiceOver and light/dark/contrast state matrix, representative per-artwork lyric contrast, and measured CPU/energy benefits also remain unverified. Do not close coordination parents or XW-12 as comprehensively accepted on the strength of the suite/package pass.

## Delivery order and dependencies

| Phase | Linear task | Deliverable | Dependency |
| --- | --- | --- | --- |
| Foundation | XW-6 | macOS 26 floor, native settings action foundation | Existing implementation; broader acceptance pending |
| 1 | XW-7 | Persistent glass menu islands; Settings category islands; combined Albums/Artists entry; immersive reveal; semantic contrast and typography | Integrated shell; acceptance tracked below |
| 2 | XW-13 | Full-height trailing queue, collection/Up Next/history and listening history | Window composition in phase 1 |
| 3 | XW-8 / XW-9 | Home/New/search/catalog/podcast/subscriptions; preserved heroes; songs/playlist layouts | Navigation shell in phase 1 |
| 4 | XW-16 | Create/import/add/sync/delete/version/metadata/notes/context actions | Playlist browsing and shared controls |
| 5 | XW-14 | Floating player, horizontal volume popover, cover/lyrics composition, lyric state/options | Queue and shared chrome |
| 6 | XW-15 | Lyric matching, video/comments/chapters, audio info/EQ, mini/menu-bar/desktop | Player and immersive presentation |
| 7 | XW-17 / XW-18 | Preferences, account, review, help/update, consent/config and diagnostics | Shared navigation/forms; permission boundaries preserved |
| Continuous + final | XW-12 | States, accessibility, keyboard and measured motion/energy verification | Continuous checks in every phase; final reconciliation last |

XW-5 coordinates the full reconstruction. XW-10 and XW-11 are coordination parents for the granular playback and operation/settings tasks. Do not mark those parents complete before their child work and acceptance pass. Sequence is a review order; unrelated low-risk changes need not wait for artificial dependencies.

## Approved combination rules

- Navigation uses three persistent groups: Search/Home, New through Playlists, and a separate Settings action. Remove expanded per-playlist navigation. Settings has adaptive category islands; hover or keyboard focus reveals readable text. Combine Albums/Artists behind one native menu while retaining separate stable model identities. Navigation islands fade only in immersive playback and reveal on pointer or keyboard interaction.
- Hero cards stay the default expressive collection surface: H0 structure, H2 center prominence, H3 optional information. 12B reduces stage height; 14A and 15A retain the complete table and cover wall. Sorting never rewrites playlist order or playback context.
- 19A+B means switchable grid/list. 25B+C means deletion preview plus version timeline. 30B+C means channel segmentation plus portrait Shorts. Multiple selections are complementary unless explicitly incompatible.
- 38B+C combines a left artwork/right lyrics composition with a restrained artwork environment and safe transport area. 40A–D combine one options menu, source/timing transparency, neutral fallback and artwork-derived current-line color.
- 49A+B combines native sections/actions with the user's persistent adaptive settings islands; do not restore a second settings rail or unrelated nested categories.
- 52B+C+D combines quality profiles, explicit cache deletion preview and pre-cache explanation. 55A–D are states of one source-pinned consent/recovery flow, not four independent permissions. 56A–D retain purpose-separated config choices. 57A–D combine source/AI settings, progressive details and support.
- Core playback, queue, persistence and auth boundaries are not redesigned merely to simplify UI. Permission expansion, remote writes and actual playback acceptance require their existing scoped safeguards.

## Skills and evidence

Use SwiftUI Expert for state/view invalidation, resizable layout, native controls, localization and accessibility. Use Build macOS Apps Liquid Glass and build/run skills for semantic glass and packaged native verification. Use Computer Use for rendered native interaction, Browser for local concept UI only, and Linear for task tracking. Performance/trace skills apply when measuring a demonstrated issue; do not add unrelated tooling or dependencies. Native glass API references: [Glass](https://developer.apple.com/documentation/swiftui/glass) and [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)).

## All 64 selected areas and ownership

| Area | Selected options | Primary task | Current evidence/status |
| --- | --- | --- | --- |
| 01 窗口与导航 | A + B | XW-7 | Implemented persistent native glass islands; entire group centered with equal 16pt gaps rendered; full keyboard/VoiceOver matrix open |
| 02 工具栏与返回语义 | A + B + C | XW-7 | Native window-local Back/Forward and immersive exit retained; main Search shares history; complete keyboard/window-restoration matrix open |
| 03 边栏选中与图标轨道 | A + B | XW-7 | Grouped capsules, semantic selection and combined catalog menu implemented; hover/focus reveal retained; complete AX traversal open |
| 04 标题、字体与内容宽度 | A + B | XW-7 | Shared 28pt SF page / 20pt section hierarchy and responsive forms implemented; expressive F3 remains; full font/appearance matrix open |
| 05 玻璃层级与颜色 | C | XW-7 | Native navigation/window glass with adaptive solid PlayerBar capsule implemented; Reduce Transparency rendered on Home/Queue/Now Playing; light/artwork matrix open |
| 06 浅色、深色和辅助显示 | A | XW-7 | Semantic colors, opaque accessibility path and neutral lyric fallback implemented; Increase Contrast empty lyrics rendered; full appearance matrix open |
| 07 首页来源与恢复提示 | B | XW-8 | Native source menu, true source/cached-origin filters and shared Account/Home recovery copy implemented; live browser/account recovery unexercised |
| 08 心情与活动 | A | XW-8 | Native horizontal capsule activities implemented; shared main Search routing retained; complete keyboard/compact traversal open |
| 09 首页精选与封面货架 | D | XW-8 | Source-labeled landscape Muses Spotlight, type-aware Top Picks and square shelves implemented; no external editorial/release metadata invented |
| 10 新发现 | A | XW-8 | Truthful library rediscovery / account / subscription-inspired provenance and source menu implemented; account identity/cancellation guards retained; live provider states open |
| 11 货架卡片及hover播放 | A | XW-8 | True read-only cover Open, separate focus-visible Play and full native More implemented; compact Spotlight More moved to artwork corner; complete focus matrix open |
| 12 歌曲默认页面 | B | XW-9 | H0/H2/H3 hero retained; bounded 260pt cover stage and reduced vertical clearance implemented; complete compact/state acceptance open |
| 13 焦点带、定位与播放仪式 | A | XW-9 | Canonical focus inputs preserved; ember effect replaced by restrained 180ms continuity outline with Reduce Motion path; full input equivalence open |
| 14 完整表格、分页和排序 | A | XW-9 | Existing native Table, visible columns, sorting and accessible paging retained; canonical order/context preserved; full keyboard/large-list runtime matrix open |
| 15 封面墙与布局记忆 | A | XW-9 | Existing adaptive lazy square cover wall, two-line titles, native actions and per-collection layout memory retained; complete wall/focus acceptance open |
| 16 专辑与艺术家 | A | XW-8 | Square album overview, circular artists and independent identity notice implemented; stable identities/cache/refresh/detail authority retained; live catalog matrix open |
| 17 音乐视频 | A | XW-8 | Track-backed 16:9 MusicVideoCollectionView with duration/video copy and full playback context implemented; populated native video matrix open |
| 18 收藏、固定与空态 | A | XW-8 | Shared native ContentUnavailableView with destination-specific search/import actions implemented; complete favorites/pins/unavailable matrix open |
| 19 全部歌单卡片 | A + B | XW-9 | Default lazy list / optional square grid and layout persistence rendered; separate named Open/Play/More retained; broader state/AX matrix open |
| 20 歌单详情标题与动作 | A | XW-9 | Existing cover/information/primary Play hierarchy retained; imported-playlist Pull/Push moved to More; authenticated sync acceptance open |
| 21 创建与导入入口 | B | XW-16 | Direct native Add menu lists Muses create, YouTube import and YouTube create; choice sheet removed; remote create not executed |
| 22 导入链接与进度 | B | XW-16 | Source / occurrence selection / confirmation import sheet implemented; only final confirmation writes, cancellation and occurrence tests passed; live import matrix open |
| 23 添加YouTube曲目与预览 | A | XW-16 | Native Search/Link preview with explicit Muses-local target and separate saved local revision implemented; actual remote Push remains separate and unexercised |
| 24 Pull、Push与冲突合并 | B | XW-16 | Side-by-side Muses/YouTube snapshot lists and explicit per-conflict resolution implemented; automatic merge preserves remote-only changes; live Pull/Push unexercised |
| 25 删除与版本恢复 | B + C | XW-16 | Affected-entry deletion preview implemented; existing revision timeline/diff/pin/restore and Recently Deleted retained; isolated delete/restore matrix open |
| 26 搜索场景和输入 | C | XW-8 | Local-only Spotlight-style quick entry wired to Cmd-F; full Search remains main-window destination/history; complete shortcut handoff matrix open |
| 27 来源与类别筛选 | B | XW-8 | Separate native source/category menus implemented and Library/empty states rendered; authenticated/remote category execution matrix open |
| 28 分组结果与目录详情 | A | XW-8 | Bounded grouped previews and stable-key See all/Show less implemented; full source playback context and main catalog history retained; populated remote matrix open |
| 29 播客关注与节目详情 | C | XW-8 | Home continuation reads true persisted episode progress and resumes via shared facade; cover preview independent of Play; followed directory/paging retained; populated native episode acceptance open |
| 30 订阅频道与Shorts | B + C | XW-8 | Discovery menu routes subscribed channels; native Videos/Shorts segments use separately verified tab sources, square channels and 9:16 Shorts; source/fallback tests passed, live channel matrix open |
| 31 历史概览与热力图 | A | XW-13 | Native range, four quiet metrics and optional heatmap/data table implemented and rendered; complete keyboard/appearance matrix open |
| 32 历史歌曲、清除与回放 | B | XW-13 | Stored timestamp/listening-duration/optional completion timeline with separate Play/Options implemented; confirmed clear preserved; isolated mutation matrix open |
| 33 队列面板和三段结构 | A | XW-13 | Full-height trailing queue with pinned current, Up Next, current collection, groups/history and explicit empty copy rendered; row identity/Options separated; broader matrix open |
| 34 队列分组、重排与Smart Shuffle | A | XW-13 | Native row/group reorder menus, drag order and Smart Shuffle explanation/Escape retained; complete isolated group/reorder mutation matrix open |
| 35 PlayerBar布局与闲置 | A | XW-14 | Responsive three-group solid floating PlayerBar and idle lyre tile implemented; unavailable actions disabled while queue/volume stay usable; full compact/idle matrix open |
| 36 进度、随机与重复 | A | XW-14 | Native keyboard/AX progress Slider and elapsed/remaining values implemented; seek commits guard media identity, shuffle/repeat expose readable values; live seek matrix open |
| 37 音量与输出 | C | XW-14 | Horizontal app-volume popover and distinct trailing Mac-wide output menu implemented; shared PlaybackService volume preserved; actual device changes not exercised |
| 38 Now Playing封面与歌词布局 | B + C | XW-14 | Left artwork/right lyrics with fixed safe dock and calm environment retained; empty lyric Match recovery and Increase Contrast inspected; representative artwork matrix open |
| 39 黑胶模式与封面连续性 | A | XW-14 | Optional circular vinyl retained with Reduce Motion and visible/reduced-visual lifecycle gates; cover continuity retained; full vinyl/runtime matrix open |
| 40 歌词显示、翻译和时序 | A + B + C + D | XW-14 | One native options menu, true source/synced/plain-text status, timing controls, neutral reading and artwork-line color implemented; fallback path retained; per-cover contrast/provider matrix open |
| 41 歌词匹配sheet与预览 | A | XW-15 | Native split candidate list / independently scrolling lyric preview / fixed confirmation implemented; search/cancellation authority retained; populated remote candidate acceptance open |
| 42 视频主窗口与浮窗 | A | XW-15 | Aspect-preserving on-demand video with visible Close and bounded native control group retained; no outer glass frame; live/floating video lifecycle acceptance open |
| 43 章节、评论与回复 | A | XW-15 | Native chapter popover and full-height trailing read-only comments pane implemented; reply/paging authority unchanged; live comments/replies matrix open |
| 44 音频信息与频谱 | A | XW-15 | Native grouped audio Form with collapsed technical details, separate output and spectrum implemented; unknown metadata remains unknown; populated metadata/device matrix open |
| 45 EQ编辑与预设保存 | B | XW-15 | Curve drag plus frequency selection, exact finite gain input, Stepper and preset validation implemented; existing preset/delete semantics retained; isolated edit/save matrix open |
| 46 迷你播放器、菜单栏和桌面歌词 | A | XW-15 | Single mini capsule and one native menu-bar popover surface retained; desktop lyrics reuse shared document/timing; full auxiliary-window/show-hide matrix open |
| 47 歌曲上下文菜单、分享和更多 | A + C | XW-16 | Shared full track menus expose separate native More and semantic action groups; real share/external targets retained; complete per-surface keyboard/action matrix open |
| 48 编辑元数据、笔记与书签 | A | XW-16 | Native metadata Form retained; notes/bookmarks use value drafts and one atomic Save with cancellation/failure handling; draft persistence tests passed; isolated native Save/Cancel matrix open |
| 49 设置结构、标题与按钮 | A + B | XW-7 | Native responsive grouped Forms, SF titles and role-specific actions implemented with existing adaptive category islands; complete focus/window matrix open |
| 50 通用、语言和通知 | A | XW-17 | Native language/notification controls with current permission status and one recovery action implemented; real OS permission transitions unexercised |
| 51 快捷键、手势和媒体权限 | D | XW-17 | Static gesture examples and one media-permission recovery action implemented; shortcuts retained; live permission/conflict matrix open |
| 52 音质、缓存和预缓存 | B + C + D | XW-17 | Quality profiles, progressive codec/cache categories, retained-scope deletion preview and pre-cache explanation implemented; actual quality reload/cache-clear matrix open |
| 53 外观、字号和字体popover | A + C | XW-17 | Native theme/text controls, three live font samples and compact scrolling font popover implemented; no family rewrite on open; complete font/appearance acceptance open |
| 54 账号连接与权限 | A + C | XW-17 | Distinct unconfigured/saved/pending/connected/expired account conclusions with progressive errors and separate permissions implemented; live OAuth/connect/revoke not exercised |
| 55 个性化首页与浏览器同意 | A + B + C + D | XW-18 | Dedicated two-step browser-pinned consent and shared Home/Account recovery implemented; dismissal/reconnect/source-identity tests passed; live cookie/session acceptance unexercised |
| 56 播放访问、cookies和解析器配置 | A + B + C + D | XW-18 | Purpose-separated native playback browser config, staged current/target/new preview and external-source location implemented; wizard no longer overwrites external config; live Apply unexercised |
| 57 歌词来源与Intelligence | A + B + C + D | XW-17 | Automatic/default lyric source, progressive provider details, matching availability popover and reading-menu default separation implemented; provider/Intelligence error matrix open |
| 58 诊断、GPU和技术路径 | B + D | XW-18 | Separate diagnostics window with Playback/Import/Account troubleshooting and progressive technical/GPU/reduced-visual controls implemented; auxiliary lifecycle matrix open |
| 59 资料库身份核对 | A + B + C | XW-17 | Native evidence Table, selected preview, Pending/Confirmed and grouped Problems with fixed apply count implemented; stable evidence guards retained; actual apply/rollback unexercised |
| 60 帮助与隐私 | A | XW-17 | Full-row native Help/Privacy disclosures with selected expansion/focus semantics implemented; complete keyboard/VoiceOver wording matrix open |
| 61 关于与更新 | A + C + D | XW-17 | Native update status/progress/result sheet, retry and unsupported-build explanation implemented; real eligible download/verification/install not exercised |
| 62 加载、空、失败与过期 | A + B + D | XW-12 | Shared/destination-specific native empty states and retained-content loading/failure/stale branches implemented; complete cross-feature state matrix open |
| 63 键盘、焦点和VoiceOver | A + C | XW-12 | Native focusable controls and separate track/Options naming implemented; complete keyboard/VoiceOver traversal and permission-window focus matrix open |
| 64 动效、滚动和能耗 | B + D | XW-12 | Restrained activation/hover, Reduce Motion and visible/reduced-visual spectrum/vinyl gates implemented; native deck/vinyl Reduce Motion checks and system preference restoration passed; measured energy/CPU benefit unproven |

## Exact option text and user notes

### 01 · 窗口与导航 (XW-7)

- 01A: 原生 NavigationSplitView + sidebar List，内容历史独立保留；系统负责栏宽与滚动边缘，推荐
- 01B: 保留图标轨道但用 AppKit split view 管理布局；更接近现状，桥接维护成本较高

User note (verbatim decision data): 微调：将左侧栏改成左侧竖置菜单岛。搜索、首页放一个岛，新发现到全部歌单放一个岛，设置单独一个按钮。不再在左侧展开列出歌单。每个岛和按钮皆为透明的液态玻璃圆形和圆角胶囊按钮。左侧菜单岛在主界面和设置页不再折叠隐藏，播放界面中鼠标移出后自动淡出，鼠标回归后正常显示。如果你不确定具体设计，我们后续仍可采用多方案选择的方式探讨这一部分。

### 02 · 工具栏与返回语义 (XW-7)

- 02A: 统一原生导航组，沉浸态仅保留有意义的返回和窗口操作，推荐
- 02B: 浏览导航左侧、播放相关动作右侧，通过 ToolbarSpacer 分组
- 02C: 沉浸态收起工具栏，指针靠近上缘显现；需保留键盘退出

### 03 · 边栏选中与图标轨道 (XW-7)

- 03A: 原生列表选择行 + 统一语义图标，金色只用于选中，推荐
- 03B: 紧凑轨道保持88pt，hover弹出标题，选中有位置指示

User note (verbatim decision data): 参考01中的设计。

### 04 · 标题、字体与内容宽度 (XW-7)

- 04A: SF Pro为主，衬线仅编辑精选与Now Playing；保留少量Muses个性，推荐
- 04B: 保留F3组合但统一标题字号、基线、层级与语言对应

### 05 · 玻璃层级与颜色 (XW-7)

- 05C: 仅窗口原生区域使用玻璃，PlayerBar为轻薄实色胶囊；更稳健

User note (verbatim decision data): 增强在不同底色的情况中的显示效果，需要动态改变字体的颜色。

### 06 · 浅色、深色和辅助显示 (XW-7)

- 06A: 同一套系统语义颜色和opaque辅助路径，推荐

### 07 · 首页来源与恢复提示 (XW-8)

- 07B: 来源菜单切换公共/账号/已导入，解释留在菜单内

### 08 · 心情与活动 (XW-8)

- 08A: 原生水平选择组，活动折入可滚动一行，推荐

### 09 · 首页精选与封面货架 (XW-8)

- 09D: 编辑精选用横图，歌单用方图，Top Picks用人像；需可靠内容类型而非硬套图形

### 10 · 新发现 (XW-8)

- 10A: 明确标注公共新发行、资料库重发现等来源，推荐

### 11 · 货架卡片及hover播放 (XW-8)

- 11A: 封面打开详情，独立hover播放按钮；AX分别命名“打开/播放/更多”，推荐

### 12 · 歌曲默认页面 (XW-9)

- 12B: 保留焦点带默认但大幅降低舞台高度，表格预览连续衔接

### 13 · 焦点带、定位与播放仪式 (XW-9)

- 13A: 保留Muses焦点带但播放只做轻微封面连续过渡，推荐

### 14 · 完整表格、分页和排序 (XW-9)

- 14A: 原生Table + 可见列标题 + 虚拟化滚动，推荐

### 15 · 封面墙与布局记忆 (XW-9)

- 15A: 自适应方形封面网格，二行标题、稳定更多动作，推荐

### 16 · 专辑与艺术家 (XW-8)

- 16A: 原生方形专辑/圆形艺术家列表 + 独立身份确认提示，推荐

User note (verbatim decision data): 把专辑和艺术家合并到一个框题（按钮）中。

### 17 · 音乐视频 (XW-8)

- 17A: 16:9缩略图网格 + 视频时长 + 视频文案，推荐

### 18 · 收藏、固定与空态 (XW-8)

- 18A: 统一ContentUnavailableView与明确搜索/导入CTA，推荐

### 19 · 全部歌单卡片 (XW-9)

- 19A: 方形封面，标题作者在外，来源/同步状态缩为单个标记，推荐
- 19B: 原生列表模式作为默认，封面网格可选

### 20 · 歌单详情标题与动作 (XW-9)

- 20A: Apple Music式封面+信息，播放为主，同步进入更多，推荐

### 21 · 创建与导入入口 (XW-16)

- 21B: 添加菜单直接列三种动作，跳过选择sheet

### 22 · 导入链接与进度 (XW-16)

- 22B: 多步骤来源预览/选择项目/确认导入；信息更清楚但耗时

### 23 · 添加YouTube曲目与预览 (XW-16)

- 23A: 搜索或链接统一原生sheet，选择后明确本地/远端目标，推荐

### 24 · Pull、Push与冲突合并 (XW-16)

- 24B: 左右本地/YouTube对照表，冲突逐项选择

### 25 · 删除与版本恢复 (XW-16)

- 25B: 删除预览列出受影响对象，保留恢复入口
- 25C: 版本按时间线展示，选中显示新增/移除/顺序变化

### 26 · 搜索场景和输入 (XW-8)

- 26C: Spotlight式快捷面板作快速入口，详细搜索仍主窗口

### 27 · 来源与类别筛选 (XW-8)

- 27B: 来源与类别分别toolbar菜单，减少横向占用

### 28 · 分组结果与目录详情 (XW-8)

- 28A: 结果分组各显示少量项+查看全部，详情使用主历史，推荐

### 29 · 播客关注与节目详情 (XW-8)

- 29C: 首页继续收听分集货架，关注页继续目录

### 30 · 订阅频道与Shorts (XW-8)

- 30B: 订阅作为发现筛选，频道详情显示长视频与Shorts分段
- 30C: 频道方卡，Shorts保持纵向媒体比例而不改播放身份

### 31 · 历史概览与热力图 (XW-13)

- 31A: 原生分段范围 + 4个轻量统计 + 可折叠热力图，推荐

### 32 · 历史歌曲、清除与回放 (XW-13)

- 32B: 紧凑封面时间线，单独显示播放时长与完成度

### 33 · 队列面板和三段结构 (XW-13)

- 33A: 原生inspector风格，当前/Up Next/历史三段明确，推荐

User note (verbatim decision data): 队列应该独占右侧，完整占据上下空间（窗口一般顶部预留标题栏，右侧栏可以进入标题栏中）

### 34 · 队列分组、重排与Smart Shuffle (XW-13)

- 34A: 原生List重排柄、完整键盘菜单，Smart Shuffle解释popover，推荐

### 35 · PlayerBar布局与闲置 (XW-14)

- 35A: Apple Music式响应式浮动胶囊，封面/运输/辅助三组，推荐

### 36 · 进度、随机与重复 (XW-14)

- 36A: 原生Slider语义，时间与剩余时间清晰，模式显示可读状态，推荐

### 37 · 音量与输出 (XW-14)

- 37C: 音量popover横向布局，输出另有右侧入口

### 38 · Now Playing封面与歌词布局 (XW-14)

- 38B: Apple Music左封面右歌词，空歌词仍给搜索恢复
- 38C: 封面全屏环境保持克制，信息与运输固定底部安全区

### 39 · 黑胶模式与封面连续性 (XW-14)

- 39A: 保留黑胶作为Muses可选个性，系统Reduce Motion静态，推荐

### 40 · 歌词显示、翻译和时序 (XW-14)

- 40A: 模式和翻译放单一原生选项菜单，原文/译文层级明确，推荐
- 40B: 歌词工具栏单独显示来源与同步状态，偏移在更多中
- 40C: 纯歌词阅读用系统文本风格，当前句仅金色强调
- 40D: 保留封面多色当前句，但其他文本中性；每张封面均验证对比度

### 41 · 歌词匹配sheet与预览 (XW-15)

- 41A: 原生双栏：紧凑搜索顶部、候选列表、正文预览、固定确认，推荐

### 42 · 视频主窗口与浮窗 (XW-15)

- 42A: 视频保留原始比例，控制组靠角落原生玻璃，关闭明显，推荐

### 43 · 章节、评论与回复 (XW-15)

- 43A: 章节原生Popover列表，评论trailing pane独立滚动，推荐

### 44 · 音频信息与频谱 (XW-15)

- 44A: 原生Form信息行，技术详情折叠、输出独立分区，推荐

### 45 · EQ编辑与预设保存 (XW-15)

- 45B: 保留曲线直接拖动，补齐键盘频段选择与精确值输入

### 46 · 迷你播放器、菜单栏和桌面歌词 (XW-15)

- 46A: 迷你播放器保留单一玻璃胶囊，菜单栏popover一层原生表面，推荐

### 47 · 歌曲上下文菜单、分享和更多 (XW-16)

- 47A: 所有曲面统一心形收藏；菜单按播放/组织/信息/外部动作分组，推荐
- 47C: 常用动作快捷行，其余原生菜单，保留完整键盘入口

### 48 · 编辑元数据、笔记与书签 (XW-16)

- 48A: 元数据原生Form；笔记与书签统一暂存、保存一次，推荐但需行为方案批准

### 49 · 设置结构、标题与按钮 (XW-7)

- 49A: 原生类别List + Form，动作使用glass/glassProminent，推荐
- 49B: 保留替换边栏，但正文标题改系统层级，宽度响应式

User note (verbatim decision data): 自适应左侧栏，改变左侧栏岛组合。外加：移到左侧岛横向展开文字说明。

### 50 · 通用、语言和通知 (XW-17)

- 50A: 系统原生Picker/Toggle，权限状态旁唯一操作，推荐

### 51 · 快捷键、手势和媒体权限 (XW-17)

- 51D: 手势演示静态图+文字，Reduce Motion一致，不用持续动画

### 52 · 音质、缓存和预缓存 (XW-17)

- 52B: 自动/省流量/高品质主选项，具体codec在详情
- 52C: 缓存概览条+可展开分类，清理先预览保留范围
- 52D: 预缓存开关展开范围和容量，只对当前来源解释生效情况

### 53 · 外观、字号和字体popover (XW-17)

- 53A: 主题原生segmented Picker，字体分系统/经典，推荐
- 53C: 显示三张实时样例：标题/曲目/歌词；便于判断字号

### 54 · 账号连接与权限 (XW-17)

- 54A: 区分会话已保存/频道待确认/配置不可用，权限独立分区，推荐
- 54C: 连接状态卡仅显示一个结论，失败详情可展开

### 55 · 个性化首页与浏览器同意 (XW-18)

- 55A: 专用原生同意sheet固定来源，状态页只显示当前来源与恢复，推荐
- 55B: 来源预览/确认两步，列出范围与清理生命周期
- 55C: 开关仅打开设置向导，不能替代专用同意
- 55D: 失败回公共首页banner与账号页同一解释，避免不同状态文案

### 56 · 播放访问、cookies和解析器配置 (XW-18)

- 56A: 浏览器选择原生Picker，配置写入前显示目标及变更预览，推荐
- 56B: 应用专用配置面板，只显示Muses使用的值
- 56C: 保留外部yt-dlp配置读取，标注来源并允许打开所在位置
- 56D: 播放访问与Web Home分别说明用途，避免误认为同一授权

### 57 · 歌词来源与Intelligence (XW-17)

- 57A: 来源原生菜单，智能匹配状态与开关同一行，推荐
- 57B: 默认自动，候选源藏高级；仅错误时显示实际来源
- 57C: 翻译/音译在歌词阅读菜单，设置只控制默认值
- 57D: 智能功能状态popover解释支持条件，错误和不可用各有恢复方式

### 58 · 诊断、GPU和技术路径 (XW-18)

- 58B: 故障向导按播放/导入/账号分类，再展技术细节
- 58D: 诊断独立辅助窗口，主设置仅入口；适合支持但增加窗口管理

### 59 · 资料库身份核对 (XW-17)

- 59A: 原生Table显示证据/置信状态，选中右侧预览，推荐
- 59B: 问题分组列表，逐项展开候选与明确差异
- 59C: 待处理/已确认分段，底部固定应用数量

### 60 · 帮助与隐私 (XW-17)

- 60A: 原生DisclosureGroup，整行可点击且焦点明确，推荐

### 61 · 关于与更新 (XW-17)

- 61A: 标准关于信息+原生更新状态区，推荐
- 61C: 更新进度和结果原生sheet，失败保留重试
- 61D: 未配置构建明确“此构建不支持自动更新”，避免永久灰按钮无解释

### 62 · 加载、空、失败与过期 (XW-12)

- 62A: 共享状态组件，短解释+唯一主要恢复动作，推荐
- 62B: 保留旧内容并顶部标记更新时间，刷新不中断
- 62D: 按页面提供针对性空态，不用同一大插画覆盖所有业务

### 63 · 键盘、焦点和VoiceOver (XW-12)

- 63A: 原生Button/List/Table优先，图标分别命名、可见系统焦点，推荐
- 63C: 曲目提供单一焦点行加动作菜单，减少重复停靠点

### 64 · 动效、滚动和能耗 (XW-12)

- 64B: 封面舞台按需动效，浏览默认静态
- 64D: 提供省电播放视觉模式，频谱/黑胶按可见性订阅；需实测收益
