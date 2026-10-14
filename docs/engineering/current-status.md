# 当前修复与验收状态

2026-10-13 发布后接续：用户授权实际操作已安装的正式版 0.6.0，并决定彻底移除公共发现，只保留 Muses 与真实账号推荐。XW-75 原含最小化、闭窗、Quick Search、framework 请求与 Now Playing Back 的完整连续路径已通过；真实歌词服务预览及浮窗上方原生弹窗也已接受。正式操作复现的 **XW-90 冷态 Play 无主窗口** 和 **XW-92 主窗口视频截获歌词弹窗键盘** 分别在 `f2ef10f`、`7481961` 修复；**XW-91 公共发现退休** 在 `a30cebd` 实现。三个修复已通过候选原生小节、受控回归和独立复审，[PR #2](https://github.com/xiaotwu/Muses-Polyhymnia/pull/2) 合并为 `9f482a5`，XW-90/91/92 均 Done。详细操作、数据恢复和限定范围见 [正式版检查](post-release-formal-inspection.md)。

本轮 XW-93 已受控确认并窄修复：旧分页不再清掉新同名请求的 loading 标记，完整刷新同步释放旧 loading/error。原始 15 个失败断言和修复后通过均保留，39 项 / 5 套件相关回归及最终独立复审通过；详见 [分页状态归属](home-continuation-ownership.md)。[PR #3](https://github.com/xiaotwu/Muses-Polyhymnia/pull/3) 的完整 [CI 38487746201](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38487746201) 全阶段成功（917 项 / 127 套件、独立磁盘恢复、14 项发布检查、元数据与打包/上传），合并为 `bc7d24e`，XW-93 Done。新 main 重复 [CI 38489943090](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38489943090) 待接续核实。

正式版新增 Queue 上方歌词 Intent 的 Tab/Escape 小节已接受。用户新报告的侧栏问题已按十二个浏览目的地和导入详情的指针封面入口检查，当前宽窗未复现稳定故障；普通歌词默认值这次是真实视频标题，但艺人仍是发布者。详细范围及资料恢复见 [输入与署名检查](post-release-input-and-credits.md)。新增 XW-94 旧账号署名、XW-95 默认歌词查询正在受控修复；XW-96 保留间歇侧栏报告及快速重开/hover/compact 条件。

Linear 当前 27 项开放：18 项 In Review、8 项 In Progress、1 项 Backlog，开放 Bug 为 XW-94/95。XW-75 仍 In Review；真实 macOS 26、手动 Siri/Shortcuts 和完整 VoiceOver 矩阵没有新增通过结论。旧公共 Home Retry 要求退休，不计为通过。

最终本机验证：912 项 / 126 套件 Swift 报告通过（27.877 秒，包含 opt-in 跳过项），14 项发布配置检查、独立磁盘恢复 1 项 / 1 套件、Release 编译与新 App Intents 元数据通过。候选冷 Play 在 Cua 读取前已记录到主窗口，新进程正确曲目推进/Pause；视频歌词 Tab/Escape、视频/章节/评论自身关闭以及 Home/New 两来源空态均通过。正式版、资料与凭据保留，全部自有候选已清理。

精确 PR head `7da9e4e` 的 [完整 macOS CI 38481575596](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38481575596) 全阶段成功：14 项发布检查、912 项 / 126 套件 Swift 报告（56.844 秒）、独立磁盘恢复 1 项 / 1 套件（0.130 秒）、元数据、预览打包和上传。合并源码与已验证源码无差异；2026-10-13 接续已确认 `main` 源码 `9f482a5` 的重复 [CI 38483286321](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38483286321) 全阶段成功：14 项发布检查（7.745 秒）、912 项 / 126 套件 Swift 报告（54.189 秒）、独立磁盘恢复 1 项 / 1 套件（0.128 秒）、元数据、预览打包和上传。文档提交 `ce061b1` 未改变该源码。当前安装的 0.6.0 保留，这些源码改动将在下一次正式发版后生效。

以下 2026-10-12 及以前记录保留为已发布基线，最新剩余条件以本文表格和正式版检查报告为准。

2026-10-10 至 12 日继续审阅后，七项确认的问题已修复并推送到 `main`。最新应用执行源码为 `8877bee`，XW-89 的受控加载回归、独立复审和原生复验均通过。`8877bee` 的 [完整 macOS CI 38217251194](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38217251194) 全阶段通过：常规运行报告 901 项测试、123 个套件（51.299 秒，包含 opt-in 跳过项），独立磁盘恢复用例另以 1 项/1 套件通过（0.112 秒）；8 项发布配置检查、App Intents 元数据、预览打包和上传均通过。

发布前 Linear 有 24 项开放：18 项 In Review、6 项 In Progress，包含父任务与协调项。XW-83/84/85/86/87/88/89 均 Done；XW-84 原生错误、草稿和 Apply 重试已完成，XW-75 已接受停止目标的歌词 Intent 冷启动。该发布前检查点的开放 Bug 标签任务为零；本次正式版新增缺陷见上文，完整产品矩阵仍有明确条件待验。

## 本次发布决定

2026-10-12，用户确认当前质量足以发布这次大更新，并明确将剩余验收、增强和优化安排到发布后。[0.6.0 已公开发布](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.0)，正式源码为 `ec6d0ec`，签名公证的 DMG/ZIP 与校验和已上传，自动更新源已切换。该提交的 [完整 CI 38306575438](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38306575438) 通过 14 项发布检查、901 项/123 套件常规 Swift 报告及独立磁盘恢复用例，元数据、预览打包和上传均通过。资产、旧 feed 条目保留与远端验证见 [发布记录](release-0.6.0.md)。24 项未完任务继续如实保留，不作为完整产品矩阵通过声明。0.6.0 要求 macOS 26 / Apple Silicon，更新源保留适配旧系统的 0.5.11。

## 已交付修复

| 任务 | 修复及证据 | 状态 |
| --- | --- | --- |
| XW-83 | `c49818a`：失败后的共享 Play/同曲外部链接重新加载，保留集合 occurrence、Up Next 与历史；先复现再修复，定向回归和完整 CI 通过 | Done |
| XW-84 | `5fe7487`：Pull 错误保留预览与冲突草稿；Local/Base/修订剪枝合并为一次关闭 autosave 的提交，失败回滚、同预览可重试 | Done；受控失败、真实磁盘错误 778，以及原生空间耗尽错误 13、27 表回滚、排序草稿保留、同面板重试与冷重开通过 |
| XW-85 | `c84d55c`：已打开的普通/导入歌单观察 metadata revision；Search 刷新当前查询的本地歌曲/笔记匹配，保留远端结果、分页和目录详情 | Done；真实导入歌单和固定 Library 查询的保存、刷新、恢复通过，保留完整 runner 收尾取消记录 |
| XW-86 | `8475d31`：两个既有 App Intents 改用 MainActor 上的共享进程内入口，移除 OpenURLIntent 自定义协议交接 | Done；13 项定向测试、元数据和完整 CI 通过；原生矩阵归 XW-75 |
| XW-87 | `03b8a1e`：歌曲 AX 标签绑定到歌曲 Button，保留独立视频按钮的用途/标题；Debug、Release 和 26 项现有回归通过 | Done；实际歌曲/视频独立 AX 标签与 28pt 命中范围通过 |
| XW-88 | `3b44632`：图库的禁用与辅助功能隐藏只作用于背景，避免歌词面板继承 disabled | Done；真实 framework query、输入框可用及 Close、图库身份、背景隔离、退出及清理通过 |
| XW-89 | `8877bee`：待加载的保存位置用于生命周期/更新检查点；显式 seek、失败重试、换曲和视频交接保持各自位置归属 | Done；109 项/11 套件回归、独立复审及真实冷启动快速退出后两处 20 秒保留通过 |

触发、修复和验证细节见 [播放/Pull/刷新修复](remaining-review-fixes.md) 与 [App Intents 交接](app-intents-handoff.md)、[图库歌词修复](gallery-lyrics-acceptance.md)。此前 XW-69/70/76/77/78/80/81/82 和 XW-79 均 Done，已接受范围继续复用，不重复运行。

## 最新原生结果

XW-75 的新停止目标 SearchLyricsIntent 冷启动与 XW-89 位置保护已通过：六次零进程确认、一次真实框架调用、正确 query、可操作字段/Close、同曲暂停和正常 Command-Q，完整 XCTest Passed 1/0（4.727 秒），无外层警告。调用开始至确认退出为 4.672 秒；退出时引擎是否已就绪未直接探测，不把耗时作为加载状态或性能结论。实际调用前后检查点的队列/会话位置均为 20,000 ms；协调方独立核对完整标量、队列 JSON、27 表和完整 xcresult 归档。旧源码真实暴露的 20 秒变 0 已先由受控回归复现再修复，两条视频时序也经审阅、复现和修正。原始失败与观察器告警保留，新候选、数据/缓存、偏好和注册已清理，12 项保护哈希一致。详见 [冷启动与位置恢复](cold-start-recovery.md)。

XW-84 使用用户提供的真实 `test`，在独立只读账号连接下导入完整 530 项、11 页，再从正式 Pull 入口生成预览。专用 128 MiB 测试卷耗尽空间后，面板显示 SQLite 错误 13，用户调整的首曲草稿仍保留；失败前后 27 张表的列类型和读取值完全一致。释放空间后，同一面板/PID 的 Apply 重试成功，530 项身份和预期顺序、Base/Remote 关系及正常冷重开均核对通过。首轮写锁等待后直接成功的无效触发单独保留。没有自然冲突，不增加冲突按钮或远端 Push 的验收结论。隔离登录、偏好、应用及测试卷已清理，十二项保护哈希一致。详见 [Pull 原生恢复](pull-native-recovery.md)。

XW-85 在 `8475d31` 隔离可写副本中完成四次原生 Save：标题更新立即反映到同一歌单详情；笔记与当前 Search query 随保存/恢复即时更新；最终清除自有笔记、恢复原标题及第 1/21 页。六份真实 SQLite 检查点核对通过，其他 654 首歌曲和 506 项集合身份/顺序保留。最终业务 test case Passed（53.492 秒）；随后的监督中断使整体 xcresult 为 Failed（业务 1 通过、runner 取消 1 失败），两者分别保留。协调方独立复核画面、数据库、12 项保护哈希和精确清理，XW-85 Done。

XW-75 已有一次真实 AppIntentsTesting 交付通过：两 Intent 返回，目标曲目时间从 0:00 推进至 0:01，Pause 生效；歌词面板显示正确 query 与无匹配终态，关闭后正常 Cmd-Q 退出。XCTest 为 1 项通过、0 失败。正常退出后的 helper 父链监督告警单独保留，不称整段监督无中断。

该测试先显式启动应用，仅覆盖运行中应用；无匹配不等于歌词提供方成功。同一复制配方会继承只读种子的 0400 权限，但已删除的 Intent 副本没有历史权限快照，因此权限问题是配方推断。保留直接调用/界面证据，不据此接受正常队列/历史持久化或自动 Intent 冷启。

`03b8a1e` 的新可写隔离副本已接受三个真实框架单元：最小化后同一窗口/PID 恢复、关窗后同一 PID 重建主窗口，以及 Quick Search 原草稿保留、关闭后首次歌词请求正确呈现。Now Playing 上的正确 query 与歌词面板关闭也已观察。后续正常启动的 Cua 对照确认基础 Command-[、真实 View→Back，以及从可见 Match Lyrics 入口关闭面板后的 Command-[ 均退出 Now Playing、恢复 PlayerBar，且仍暂停、音量 0%。该对照没有重放原先包含关窗、Quick Search 和 framework 请求的完整串行路径，因此保留 XCTest 超时，不称整轮通过。实例在前台离开后按精确 PID 合作退出；协调方独立核对 8 项保护哈希一致、原始 seed 仍为 0400、自有进程为零，且隔离产品、数据、偏好和 runner 容器均已移除。27 表审计保留 ORM/会话时戳变化及既有恢复路径填入的 9 个 historyRecordID，不声称所有持久化字节不变。

XW-88 已完成。图库上方的歌词面板原先继承了背景禁用状态；`3b44632` 将禁用和辅助功能隐藏限于背景内容。修复后的真实 framework query、输入框可用及 Close、同一歌曲图库保留、背景 AX 隔离、Done 返回和正常 Command-Q 退出均通过；完整 XCTest Passed 1/0（15.09 秒）。协调方独立复核四张窗口图、停止后的 SQLite、八项保护哈希和精确清理。空链接 import overlay 的歌词交接也已接受，但该旧轮退出失败且没有重置前的 import 数据库检查点，保留这两个限制。详见 [图库歌词修复](gallery-lyrics-acceptance.md)。

普通 Playlist 的独立小节已通过：新建并追加两首既有曲目、核对实际身份/顺序、在保留详情中保存标题并即时刷新、恢复原标题，以及按两项预览删除自有歌单。Cua 操作完成两次 Save；协调方独立核对七个 SQLite 检查点，655 首 Track、60 条播放事件及原有集合真值保留。前三次私有测试失败和其中一次实际播放副作用单独保留，本轮不借用 XCTest 通过结论。详见 [普通歌单验收](ordinary-playlist-metadata.md)。

XW-73 新增一项完整原生小节：真实导入 Roselia 的 24 首 YouTube Music 专辑，非空 Albums、全部曲目详情、概览 Refresh Catalog、返回及 Artists 概览均已核对。刷新后身份/顺序保持一致，Track 为 655→679；十份检查点和协调方独立审计确认原有集合、笔记、历史及队列语义保留，隔离应用与缓存已清理。仅接受这次正常刷新，未捕获瞬时 loading，也未覆盖专辑播放、艺人详情或错误 Retry。详见 [非空目录验收](library-catalog-acceptance.md)。

XW-75 的唯一名称 Shortcuts 候选已完成注册、独立 setup 启动/退出和来源核查。搜索出现两个动作，但 Info 未给出可核实的唯一应用来源；没有创建快捷指令或执行 Intent，该次调查未接受自动冷启；后续精确框架冷启动已在上文单独通过。四份实际检查点与清理已复核，详见 [App Intents 调查](app-intents-handoff.md#stopped-target-and-shortcuts-identity-investigation)。

## 剩余条件

| 范围 | 下一步与实际前提 |
| --- | --- |
| XW-75 App Intents | 冷态歌词、完整串行键盘路径、真实来源预览/浮窗弹窗、修复后的冷 Play 和主窗口视频弹窗键盘均按记录范围通过。剩余其他未测呈现状态、手动 Siri/Shortcuts、实际 macOS 26 及完整 VoiceOver/设备矩阵。 |
| XW-26 Pull/播放父项 | XW-84 的原生错误与同草稿重试已关闭，见 [原生恢复](pull-native-recovery.md)。父项保留真实评论/回复、其它来源/视频和未测持久化分支；自然远端冲突、Push/manage 与破坏性历史/group 保持原排除范围。 |
| XW-71 Settings | 十类设置/历史、字体指针/键盘、语言/字号恢复和 Dark 840×804 三项检查已接受。剩余 Help 的 Tab/Space 与原按钮焦点、完整 VoiceOver、实际 macOS 26。 |
| XW-72 辅助窗口 | MiniPlayer 生命周期/Pin/共享播放、真实同步桌面歌词和菜单栏 Escape/音量已接受。剩余物理控件交接/完整焦点、真实未同步歌词、系统 Dark 菜单栏。 |
| XW-73 来源、XW-62 评论 | XW-91 公共 Home 与自动公开推荐退休已 Done，两来源、缓存来源与取消/禁用边界通过本轮记录范围。旧公共 Home Retry 条件退休。非空 Library Albums/详情/正常刷新/Back 与 Artists 概览仍已接受。剩余身份匹配且专门同意的真实 Web Home、其他目录/平台矩阵及非空评论回复；现有评论权限返回 insufficientPermissions。 |
| XW-93 加载标记归属 | Done；两条受控状态缺陷已修复，39 项 / 5 套件回归、独立复审和完整 CI 通过，PR #3 已集成。不增加原生、真实 Web 来源或旧内容泄漏结论。 |
| XW-94/95 署名和歌词默认查询 | In Progress；先受控验证旧 owner/重新导入/冷上下文，以及 metadata 晚到/placeholder/默认艺人。保留手工编辑和显式 query，不把数字验收参数当作自动查询缺陷。 |
| XW-96 间歇侧栏 | Backlog；本轮十三个指针入口的宽窗稳定画面均未复现。继续实际 hover/focus、compact、其它外观及退出过渡内快速重开，保留用户报告。 |
| XW-74 性能 | 获准八次真实位移和 24 次输入边界已通过；私有生命周期脚本的 29 项模拟检查通过。旧录制在末次输入后因覆盖中断提前停止，仍缺正常保存的帧记录、完整 AX 对照和事件/锚点归因；无 FPS、能耗或泄漏改善结论。 |

最新 64 区域映射见 [验收对照](../ui-ux-acceptance-reconciliation.md)。没有新增已批准但完全缺失的产品功能。系统、账号、真实来源和测量前提由现有任务管理，不通过构造来源或扩大权限填补证据。

2026-10-12 本轮完成 XW-84 原生恢复、XW-75 歌词冷启动，以及新发现 XW-89 的完整修复/复验小节。0.6.0 发布后先处理 XW-75 原含关窗、Quick Search、framework 请求和歌词关闭的串行键盘路径，再按已具备条件的剩余呈现状态推进。这一旧公共 Home Retry 顺序已由 2026-10-13 用户的功能退休决定取代；已完成且仍有效范围继续复用。

## 协作与证据

源码/构建/测试/Git 与原生阶段互斥；使用独立 namespace、精确 PID/窗口和完成标记。原始 seed 保持 0400，只有自有可丢弃副本设为 0600。停止前的实际数据库核对与恢复后的副本核对分别记录；正常应用、资料、偏好、Keychain 和当前构建保留。

私有证据位于 `~/.muses/tmp/engineering-oct08/round-3/`、`round-4/` 与 `round-5/`。完成标记表示阶段结束和清理，必须结合通过字段解释。已归并并可恢复归档的历史/完成对话共 23 个；未完验收的执行对话保留。文档分类见 [工作索引](README.md)。
