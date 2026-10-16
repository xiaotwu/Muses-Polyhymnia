# 技术工作索引与对话归并

2026-10-15 最新接续：[EQ 与外部歌词返回](eq-lyrics-return-acceptance.md) 的 XW-102 窄修复已通过本机回归与限定原生小节：同一新进程内，两份新请求分别以可见 Close 和 Save As 等待／Cancel 后 Tab／Escape 返回原 4k EQ；完整框架各 Passed 1/0。活跃 Save As 跨请求的文本保留已接受，Cancel 后重开草稿没有接受，原版两独立 PID 的失败对照保留。998 项／134 套件、发布／磁盘检查、Release、静态资格、框架及闭合资料／20 项偏好／正式版保护独立审计通过；自有资源已核验归档并按精确路径清理，原始请求、种子和检查点保留。集成状态见本修复 PR／Linear 实时记录，XW-75 继续 In Review，正式 0.6.0 未更新。

[模糊／精确歌词搜索](lyrics-search-modes.md) 的 XW-101 已 Done，PR #9 合并 `1094dbf`，精确 [PR CI 38822515891](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38822515891) 与 [main CI 38824085026](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38824085026) 全阶段成功，父引用 `46d3e6d` 已推送；正式 0.6.0 尚未更新。[音频信息与外部歌词交接](audio-info-intent-acceptance.md) 的已接受小节和原传递失败／资格更正保持原范围。正式版是用户授权重新安装、校验且未启动的干净基线；新真实暂停种子保留，不将已清除的旧资料写成恢复。最新范围见 [当前状态](current-status.md)。

2026-10-14 修复前历史检查点：[艺人目录原生接续](artist-catalog-acceptance.md)：Roselia 详情、真实在线重读、人工专辑末端和 Back/退出已按范围记录，候选已清理；首轮辅助功能滚动崩溃由 XW-100 独立追踪，正常资料的后来播放/会话变化已独立核对保留，五个简化诊断各一次 AX 动作成功，未复现复杂页面崩溃且不构成修复；原包核验归档、诊断资源清理完成，下一步须建立真实页面可重复触发。XW-73 保持 In Review；该检查点当时为 25 项开放（18 In Review、7 In Progress），唯一开放 Bug 为 XW-100。其后 XW-100 已由 PR #8 修复并 Done，当前结论见状态文档。

2026-10-14，[导入署名与封面呈现](credits-and-cover-followup.md)（XW-97/98）已完成并为 **Done**：旧 owner 署名的显式预览/可恢复修复/撤销，歌曲与歌单 3:4 焦点卡、多张 Muses 聚焦横栏和封面分辨率选择均通过限定本机/隔离原生验收。[PR #6](https://github.com/xiaotwu/Muses-Polyhymnia/pull/6) 已合并，精确 PR 与 main CI 全阶段通过；正式 0.6.0 未替换，正常资料未应用修复。

2026-10-14 最新验收：[未保存歌曲信息草稿与外部歌词 Intent 交接](edit-draft-intent-acceptance.md) 已接受同一 Title 草稿保留、Cancel 后原 query、Tab/Escape 小节，完整框架 Passed 1/0/exit0 和正常资料保护通过。XW-71 的四个 Help disclosure 在本轮单独授权的临时 Keyboard navigation 2 下通过 Tab/Space；[XW-99 信息弹窗 Escape](settings-info-escape-acceptance.md) 的窄修复通过本机 Release、独立审阅及限定原生复验，原焦点保留、继续 Tab、点击打开和人类文本选中 Escape 按范围接受。[PR #7](https://github.com/xiaotwu/Muses-Polyhymnia/pull/7) 已合并 `fc339c8`，[PR CI 38653245594](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38653245594) 与 [main CI 38654810970](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38654810970) 全阶段成功，合并源码与已验源码一致，XW-99 为 **Done**。完整数据/偏好与清理独立复核通过；系统恢复 0，自有资源已清理，正式 0.6.0 未替换。XW-71 与 XW-75 继续 In Review，其他系统、设备与未测条件保留。该历史检查点为 24 项开放（18 In Review、6 In Progress）、当时开放 Bug 标签为零；最新检查点见本文顶部，父任务与协调项仍包含在计数中。详见 [当前状态](current-status.md)。

2026-10-14 最新入口：[XW-96 导航验收](now-playing-navigation-acceptance.md) 按用户的人类实际操作判断收尾为 **Done**，转向其他主要问题。真实hover修复、普通重开、紧凑纯文本滚动及授权临时模式2的原生焦点路径按范围接受，系统已恢复0及General页面；严格小于300ms输入计时仍未验证，不再阻断后续工作，不扩展为完整设备/VoiceOver矩阵通过。

[PR #5](https://github.com/xiaotwu/Muses-Polyhymnia/pull/5) 已合并为 `ceb2e295571b89d3bc6a6da11571d0eb526383cf`；精确head `1e377954` 的 [CI 38514615922](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38514615922) 与合并 main [CI 38517976309](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38517976309) 全阶段通过，源码与已验 head 一致。正式0.6.0未替换，修复在下一版生效。自有候选/录制/观察会话结束，测试bundle、独立data/cache/偏好域和临时编译产品已清理，私有证据保留；正式后来状态未回滚。时序拒绝、退出方式和数据边界以 [当前状态](current-status.md) 及导航报告最新小节为准。

发布后新小节见 [正式版检查与修复](post-release-formal-inspection.md)：XW-90/92 的正式版缺陷和 XW-91 公共发现退休已通过候选复验、独立审阅与完整 CI，[PR #2](https://github.com/xiaotwu/Muses-Polyhymnia/pull/2) 已合并，三项 Done，重复 main CI 已确认成功。[XW-93 分页状态归属](home-continuation-ownership.md) 通过受控复现、窄修复、独立复审及完整 CI，[PR #3](https://github.com/xiaotwu/Muses-Polyhymnia/pull/3) 已合并。[Queue/封面输入与署名检查](post-release-input-and-credits.md) 的 XW-94/95 已修复、复审并通过 PR #4 完整 CI（944 项 / 129 套件），XW-95 的新签名隔离 Release 歌词输入小节已通过；[PR #4](https://github.com/xiaotwu/Muses-Polyhymnia/pull/4) 合并为 `377ad48`，两项 Done，重复 [main CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38498051238) 也全阶段成功，计数与限定范围见 [当前状态](current-status.md)。[XW-96 导航剩余验收](now-playing-navigation-acceptance.md) 的早期 Dark 实际840×804pt后台侧栏与本份纯文本歌词首末段滚动/往返小节继续保留限定范围；其最新hover修复见本文顶部。2026-10-13检查点记录25项开放（18 In Review、7 In Progress、0 Backlog）。XW-75 仍有系统/设备条件，XW-73 仍有真实账号/目录条件；下文发布前检查点保留历史范围，已安装的 0.6.0 未更新。

更新时间：2026-10-14 UTC。当前工作入口是 Codex 对话「整理并执行Linear剩余任务」。近期列表之外，已补查旧项目路径的十四个较早对话；二十二个历史对话及一个已完成的执行对话均已归并，可恢复归档，共二十三个。归档不表示其中提及的所有验收都通过，也不删除历史证据。

2026-10-13历史检查点：释放桌面后的 [XW-96 输入诊断](now-playing-navigation-acceptance.md#接续释放桌面后的输入诊断) 已完成：driver 只 warp 光标，真实 hover 尚未成立；当前系统键盘导航关闭，按钮焦点未取得。人工指针/菜单核验已准备，自动化输入暂停，正常 Muses 留在 Now Playing；最终表面/指针/前台恢复待人工小节结束。当前资料/偏好检查点保持，未改源码，XW-96 仍 In Progress。

最新结果和接续条件见 [当前状态](current-status.md)。XW-83/84/85/86/87/88/89 已完成；XW-84 的 [原生错误、草稿及 Apply 重试](pull-native-recovery.md)，以及 XW-75 歌词冷启动和 XW-89 [播放位置保护](cold-start-recovery.md) 均已接受。2026-10-12发布前检查点的执行源码为 `8877bee`。`8877bee` 的 [完整 macOS CI 38217251194](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38217251194) 全阶段通过：常规运行报告 901 项测试、123 个套件（51.299 秒，包含 opt-in 跳过项），独立磁盘恢复用例另以 1 项/1 套件通过（0.112 秒）；8 项发布配置检查、App Intents 元数据、预览打包和上传均通过。 该发布前检查点的 Linear 有24项开放（18项In Review、6项In Progress），包含父任务与协调项；Bug标签开放为零只属于该历史检查点；后来 XW-96 曾转为 In Progress / Bug，现已按用户验收决定 Done。[0.6.0 已发布](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.0)：`ec6d0ec` 的完整 CI、正式签名公证、资产与自动更新源远端核验均通过，详见 [发布记录](release-0.6.0.md)。剩余 24 项安排到发布后，优先 XW-75 原串行键盘路径及其余具体呈现状态。完整产品矩阵尚未全部通过。

本目录将仍有效的结论分为三类，并由 Linear 管理执行状态：

| 分类 | 技术文档 | 执行任务 |
| --- | --- | --- |
| 已证实的缺陷与修复 | [修复任务](repairs.md)、[来源修复](source-state-acceptance.md)、[CI 回归](source-ci-regression.md)、[缓存恢复](source-cache-recovery.md)、[重试/Pull/刷新/标签](remaining-review-fixes.md)、[App Intents](app-intents-handoff.md)、[图库歌词](gallery-lyrics-acceptance.md)、[普通歌单](ordinary-playlist-metadata.md)、[真实磁盘恢复](pull-disk-recovery.md)、[Pull 原生恢复](pull-native-recovery.md)、[冷启动与位置恢复](cold-start-recovery.md)、[信息弹窗 Escape](settings-info-escape-acceptance.md)、[EQ 歌词返回](eq-lyrics-return-acceptance.md) | 新修复及证据以 [当前状态](current-status.md) 为准；XW-84/89/99 已 Done；XW-102 本机回归／限定原生返回通过，集成见实时任务／PR；原失败与草稿边界保留 |
| 功能实现与补充验收 | [功能及验收](feature-acceptance.md)、[草稿/历史跟进](playlist-flow-followup.md)、[非空目录验收](library-catalog-acceptance.md)、[Edit Info 草稿与 Intent](edit-draft-intent-acceptance.md) | XW-79 已完成；XW-73 已补齐 24 首真实专辑的非空目录/正常刷新小节，XW-75 已接受本轮 Title 草稿交接；XW-71、XW-72、XW-73、XW-75、XW-62 与既有阶段任务保留各自剩余条件 |
| 性能与优化调查 | [优化项](performance.md) | XW-74；无证据的排查候选不直接变成重构任务 |

判断顺序：当前用户决定和批准规格 → 当前源码 → 实际运行 → 测试 → 历史记录。历史对话不能恢复已淘汰产品方向；测试通过不能替代原生界面验收。总体 UI 验收仍使用 [64 区域对照表](../ui-ux-acceptance-reconciliation.md)，具体操作使用 [验收记录](../ui-ux-redesign-acceptance.md)。

## 归并的历史来源

以下均已读取实际对话；标题按应用返回值保留。源码、测试、运行记录和当前 Linear 状态决定哪些结论仍有效。

| 对话 | 保留的有效结论 | 已淘汰或不得重新推断的内容 |
| --- | --- | --- |
| 继续完成 XW 验收任务 | 506 项队列冷恢复、实际连续旅程、测量条件、恢复与清理；详见 [本机报告](../ui-ux-final-local-session.md) | 早期剩余顺序已由当前子任务接续；不把外部条件或未执行分支算作通过 |
| 审查并重设计 macOS UI/UX | 已批准的原生导航、G1/F3、歌曲表格与沉浸播放合同；已修复的具体缺陷 | 中间候选、临时布局和已被当前源码替换的设计方案 |
| Fix Muses playback and navigation | 歌词匹配双栏工作台、媒体署名、独立浏览器授权和恢复边界 | 旧菜单栏或旧页面布局不是当前实现规范；先前 Home 失败不等于当前已证实回归 |
| 修复歌词、热键和页面问题 | 主窗口 Search、真实 Back/Forward、Settings 集成、原生控制样式与已发布版本证据 | 旧验收包、旧 Settings 分类；不重复要求已完成发布 |
| 优化歌曲与播放器页面布局 | 保留稳定 YouTube 身份的 Albums/Artists、真实媒体署名、集合播放上下文 | 曾讨论移除 Albums/Artists 的备选已被当前 D2 决定取代 |
| 设计应用自动更新系统 | Sparkle 安装、保存与清理边界；当前 [更新技术文档](../automatic-updates.md) | 旧发布门槛、版本号和旧检查清单不能自动变为本轮发布授权 |
| Rename macOS project to Muses-Polyh高 | 仓库及 macOS 项目已改名；安装应用仍称 Muses，家族网站属父仓库 | 已完成命名任务不再进入待办；旧路径仅为兼容入口 |
| 修复 GitHub Actions 并移除 Claude | 已有 CI 包装修复；贡献者 API 与首页缓存不一致的历史观察、定时检查已取消 | 未请求重建仓库；本轮不删除 Releases 或改写历史。用户明确要求归档该对话 |
| 更新项目文档与演示 | 网站导航/文档链接及设计一致性已完成的限定记录 | 当时的网站属于旧路径；当前家族网站由父仓库维护，不重新发布子仓库 Pages |
| 实施这个计划 | 旧版 Home 真实连续分页、音量接管与静音长时运行、图标完整画面 | 限定旧版/当时账号条件；macOS 14 已被当前系统门槛取代 |
| 清理本机 Muses 测试构建 | 应用包与用户库/Keychain 分离；保留凭据会导致重新打开仍已登录 | 旧清空/权限清理是已执行历史操作，不是本轮删除数据授权 |
| Review fix progress | 只补剩余矩阵和低干扰测量、不重复通过项的交接原则 | 已永久删除的旧 trace 不声称仍可重新核验；使用当前保留证据 |
| 优化选中框与页面交互体验 | 原生选中与交互、已发布版本的限定结论 | 旧版清空本机数据/凭据指令已结束，不在本轮重复执行 |
| 全面排查 Muses 项目问题 | 大型原生表格 AX 路径、分页按钮列表替代、队列随机持久顺序、实际聆听计量及保存失败反馈 | 已修复逻辑通过当前源码/测试复核；真实 VoiceOver、唤醒等仍有边界 |
| 重构 YouTube 推荐架构 | 来源分层、缓存隔离、身份核验、取消与错误展示的演进 | 旧本地生成推荐和旧 Home 管线不作为当前产品方向 |
| 修复 R009 R016 | 稳定目录、同步预览、后续播客与视频需求的历史起点 | 当时未实现的播客/Shorts 已有当前实现；远端互动写入被当前只读边界取代 |
| 修复 R011 和 R019 | 已提交的账号、导航、播放修复记录 | 不重新恢复旧图标未提交状态或旧发布包 |
| 执行 Muses 剩余修复计划 | 分开记录未实现、待验、外部条件与批准范围调整的原则 | 旧 0.5.0 ad-hoc/OAuth 构建限制不当作当前正式发布结论 |
| 重命名 logo-and-icon 为 assets | 已完成资源路径调整 | 不重新执行重命名或恢复旧路径 |
| 清理仓库中的 Claude 内容 | 历史归属与贡献者 API 已清理的记录 | 本轮不重写历史、不强推、不删除版本 |
| 集成 Kaset 功能并重设计设置 | 原生音频、共享队列、稳定多发行身份、播客、Smart Shuffle、官方字幕/画质与 App Intents 的范围分析 | 评论/订阅写入、冷启浏览恢复等早期方案须对照当前决定与源码；不自动实施 |
| 清理低优先级能力项 | 早期窗口与 Retry 限定验收 | 660×520 独立 Settings、旧词标和独立 Search 被当前集成合同取代 |

归档对话 ID 与精简核对清单保存在私有 `~/.muses/acceptance/com.muses.acceptance.settings-oct08/evidence/conversation-cleanup.json`。历史对话仍可恢复，截图、账号资料及库数据不进入仓库。

2026-10-10 另行归档的「Muses · XW-79 歌单草稿与队列历史剩余验收」已把有效结果提交至 [草稿与尾曲报告](playlist-flow-followup.md)：真实 506 项上下文、自然停止/循环、完整恢复及清理。协调清单 `~/.muses/tmp/engineering-oct08/coordinator/continuation-20261009.json` 保留该次可恢复归档与证据位置。其父任务 XW-26 仍有独立验收条件。

## 当前执行顺序

用户已授权分对话执行；并行读取、互斥修改和原生顺序见 [执行协调](execution-coordination.md)。以下是已执行的依赖顺序；当前完成结果及剩余条件以 [当前状态](current-status.md) 为准，不重新从 XW-71/72 开始整轮。

1. XW-70：恢复原有 macos-26 / Swift 6.3.3 CI 编译、测试、App Intents 和包装检查；不通过升级 runner 或跳过测试掩盖问题。
2. XW-69：旧 Desktop 分类重定向到实际拥有桌面控件的 General，完成序列化恢复/历史回归及原生所有权检查。
3. XW-71、XW-72：按具体剩余状态执行 Settings 与辅助窗口验收；同一原生实例由一个顺序执行者操作。
4. XW-73：补充真正可到达的来源、缓存、失败与取消状态；保留外部账号/权限限制。
5. XW-74：先测量普通指针滚动与工具开销，再决定是否存在可修复热点。
6. XW-75：XW-86 已修复共享进程内交接；按 [交接报告](app-intents-handoff.md) 复用真实框架证据，只继续具体未验收的窗口/系统条件。

新增任务是现有父任务的具体子项，不替代 XW-25/26/19/27 或阶段协调任务。父任务需在各自剩余条件完成后审查；In Review 表示实现待验收，不能批量标记 Done。未安排虚构的截止日期或未经批准的新功能。

## 授权与验收边界

早期验收使用隔离的 `com.muses.acceptance.*` 实例；2026-10-13 用户另行授权正式版实际操作，其范围、前后库审计和恢复见 [正式版检查](post-release-formal-inspection.md)。源码修复后的候选继续隔离验证；早期歌单操作限于 `test`，后续补验另行限定为自有可丢弃的普通 Playlist。阶段性测试配置不构成永久产品或用户限制，接续范围以当前用户授权和具体任务为准。保留生产数据、Keychain、普通应用与正常构建。旧隔离验收不操作 Liked；后续授权浏览原有 Liked 导入歌单但不改写它。不执行远端写入、权限扩张、输出设备变化，也不安装到正常应用。OS 辅助功能/显示设置保持原有范围；2026-10-14 用户单独授权的本轮 Settings Keyboard navigation 0→2→0 已在 UI 恢复，不扩展为其他系统设置授权。完整 VoiceOver/显示矩阵、实际 macOS 26 原生运行、非空订阅账号与评论权限限制仍分别记录，不能由 macOS CI runner 或模拟数据代替。

每轮保存具体源码、系统、窗口、数据及操作条件；恢复临时偏好后正常退出，核对原始数据/偏好和精确进程所有权，再清理自建构建与缓存。2026-10-12 用户已明确授权本次 0.6.0 打包与 GitHub 发布；这不等于安装到当前正常应用，也不关闭发布后的未验收条件。
