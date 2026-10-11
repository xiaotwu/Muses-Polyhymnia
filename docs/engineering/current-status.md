# 当前修复与验收状态

2026-10-10 至 11 日继续审阅后，六项确认的问题已修复并推送到 `main`。测试与 CI 提交 `8a58f7b` 的 [完整 macOS CI 38149867942](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38149867942) 全阶段通过：常规运行报告 896 项测试、123 个套件（53.867 秒），独立磁盘用例在其中跳过后另以 1 项/1 套件通过（0.144 秒）；8 项发布配置检查、App Intents 元数据、预览打包和上传均通过。应用执行源码仍为 `3b44632`。

Linear 当前有 25 项开放：19 项 In Review、6 项 In Progress，包含父任务与协调项。XW-83/85/86/87/88 均 Done；唯一开放的 Bug 标签任务 XW-84 已完成代码修复，真实磁盘写入失败/恢复已通过，保留原生错误与草稿验收。开放任务数不等于未修复缺陷数。

## 已交付修复

| 任务 | 修复及证据 | 状态 |
| --- | --- | --- |
| XW-83 | `c49818a`：失败后的共享 Play/同曲外部链接重新加载，保留集合 occurrence、Up Next 与历史；先复现再修复，定向回归和完整 CI 通过 | Done |
| XW-84 | `5fe7487`：Pull 错误保留预览与冲突草稿；Local/Base/修订剪枝合并为一次关闭 autosave 的提交，失败回滚、同预览可重试 | In Review；受控失败及真实磁盘错误 778 的回滚/同预览重试/新容器重开通过，原生错误与草稿展示待验 |
| XW-85 | `c84d55c`：已打开的普通/导入歌单观察 metadata revision；Search 刷新当前查询的本地歌曲/笔记匹配，保留远端结果、分页和目录详情 | Done；真实导入歌单和固定 Library 查询的保存、刷新、恢复通过，保留完整 runner 收尾取消记录 |
| XW-86 | `8475d31`：两个既有 App Intents 改用 MainActor 上的共享进程内入口，移除 OpenURLIntent 自定义协议交接 | Done；13 项定向测试、元数据和完整 CI 通过；原生矩阵归 XW-75 |
| XW-87 | `03b8a1e`：歌曲 AX 标签绑定到歌曲 Button，保留独立视频按钮的用途/标题；Debug、Release 和 26 项现有回归通过 | Done；实际歌曲/视频独立 AX 标签与 28pt 命中范围通过 |
| XW-88 | `3b44632`：图库的禁用与辅助功能隐藏只作用于背景，避免歌词面板继承 disabled | Done；真实 framework query、输入框可用及 Close、图库身份、背景隔离、退出及清理通过 |

触发、修复和验证细节见 [播放/Pull/刷新修复](remaining-review-fixes.md) 与 [App Intents 交接](app-intents-handoff.md)、[图库歌词修复](gallery-lyrics-acceptance.md)。此前 XW-69/70/76/77/78/80/81/82 和 XW-79 均 Done，已接受范围继续复用，不重复运行。

## 最新原生结果

XW-85 在 `8475d31` 隔离可写副本中完成四次原生 Save：标题更新立即反映到同一歌单详情；笔记与当前 Search query 随保存/恢复即时更新；最终清除自有笔记、恢复原标题及第 1/21 页。六份真实 SQLite 检查点核对通过，其他 654 首歌曲和 506 项集合身份/顺序保留。最终业务 test case Passed（53.492 秒）；随后的监督中断使整体 xcresult 为 Failed（业务 1 通过、runner 取消 1 失败），两者分别保留。协调方独立复核画面、数据库、12 项保护哈希和精确清理，XW-85 Done。

XW-75 已有一次真实 AppIntentsTesting 交付通过：两 Intent 返回，目标曲目时间从 0:00 推进至 0:01，Pause 生效；歌词面板显示正确 query 与无匹配终态，关闭后正常 Cmd-Q 退出。XCTest 为 1 项通过、0 失败。正常退出后的 helper 父链监督告警单独保留，不称整段监督无中断。

该测试先显式启动应用，仅覆盖运行中应用；无匹配不等于歌词提供方成功。同一复制配方会继承只读种子的 0400 权限，但已删除的 Intent 副本没有历史权限快照，因此权限问题是配方推断。保留直接调用/界面证据，不据此接受正常队列/历史持久化或自动 Intent 冷启。

`03b8a1e` 的新可写隔离副本已接受三个真实框架单元：最小化后同一窗口/PID 恢复、关窗后同一 PID 重建主窗口，以及 Quick Search 原草稿保留、关闭后首次歌词请求正确呈现。Now Playing 上的正确 query 与歌词面板关闭也已观察。后续正常启动的 Cua 对照确认基础 Command-[、真实 View→Back，以及从可见 Match Lyrics 入口关闭面板后的 Command-[ 均退出 Now Playing、恢复 PlayerBar，且仍暂停、音量 0%。该对照没有重放原先包含关窗、Quick Search 和 framework 请求的完整串行路径，因此保留 XCTest 超时，不称整轮通过。实例在前台离开后按精确 PID 合作退出；协调方独立核对 8 项保护哈希一致、原始 seed 仍为 0400、自有进程为零，且隔离产品、数据、偏好和 runner 容器均已移除。27 表审计保留 ORM/会话时戳变化及既有恢复路径填入的 9 个 historyRecordID，不声称所有持久化字节不变。

XW-88 已完成。图库上方的歌词面板原先继承了背景禁用状态；`3b44632` 将禁用和辅助功能隐藏限于背景内容。修复后的真实 framework query、输入框可用及 Close、同一歌曲图库保留、背景 AX 隔离、Done 返回和正常 Command-Q 退出均通过；完整 XCTest Passed 1/0（15.09 秒）。协调方独立复核四张窗口图、停止后的 SQLite、八项保护哈希和精确清理。空链接 import overlay 的歌词交接也已接受，但该旧轮退出失败且没有重置前的 import 数据库检查点，保留这两个限制。详见 [图库歌词修复](gallery-lyrics-acceptance.md)。

普通 Playlist 的独立小节已通过：新建并追加两首既有曲目、核对实际身份/顺序、在保留详情中保存标题并即时刷新、恢复原标题，以及按两项预览删除自有歌单。Cua 操作完成两次 Save；协调方独立核对七个 SQLite 检查点，655 首 Track、60 条播放事件及原有集合真值保留。前三次私有测试失败和其中一次实际播放副作用单独保留，本轮不借用 XCTest 通过结论。详见 [普通歌单验收](ordinary-playlist-metadata.md)。

XW-73 新增一项完整原生小节：真实导入 Roselia 的 24 首 YouTube Music 专辑，非空 Albums、全部曲目详情、概览 Refresh Catalog、返回及 Artists 概览均已核对。刷新后身份/顺序保持一致，Track 为 655→679；十份检查点和协调方独立审计确认原有集合、笔记、历史及队列语义保留，隔离应用与缓存已清理。仅接受这次正常刷新，未捕获瞬时 loading，也未覆盖专辑播放、艺人详情或错误 Retry。详见 [非空目录验收](library-catalog-acceptance.md)。

XW-75 的唯一名称 Shortcuts 候选已完成注册、独立 setup 启动/退出和来源核查。搜索出现两个动作，但 Info 未给出可核实的唯一应用来源；没有创建快捷指令或执行 Intent，因此自动冷启仍未接受。四份实际检查点与清理已复核，详见 [App Intents 调查](app-intents-handoff.md#stopped-target-and-shortcuts-identity-investigation)。

## 剩余条件

| 范围 | 下一步与实际前提 |
| --- | --- |
| XW-75 App Intents | 自动停止进程后的 Intent 冷启；原含关窗、Quick Search、framework 请求及关闭歌词后的完整串行键盘路径；视频与其他未测呈现状态；手动 Siri/Shortcuts、实际 macOS 26 及完整 VoiceOver/设备矩阵。空链接 import 与图库歌词单元已按各自范围接受。 |
| XW-84、XW-26 | 原生 Pull 失败的错误/草稿保留和点击 Apply 重试。真实磁盘写入错误 778 的回滚、同预览重试与新容器重开已通过，见 [磁盘回归](pull-disk-recovery.md)。既有来源失败仅限匿名 yt-dlp 导入，不能证明已认证 Data API Pull 不可用；真实预览仍需连接只读账号、身份匹配和完整远端快照。原子保存和受控失败回归继续有效。远端 Push/manage 与破坏性历史/group 保持原排除范围。 |
| XW-71 Settings | 十类设置/历史、字体指针/键盘、语言/字号恢复和 Dark 840×804 三项检查已接受。剩余 Help 的 Tab/Space 与原按钮焦点、完整 VoiceOver、实际 macOS 26。 |
| XW-72 辅助窗口 | MiniPlayer 生命周期/Pin/共享播放、真实同步桌面歌词和菜单栏 Escape/音量已接受。剩余物理控件交接/完整焦点、真实未同步歌词、系统 Dark 菜单栏。 |
| XW-73 来源、XW-62 评论 | 匿名 Home 加载/缓存/过期恢复、真实目录/集合上下文及缓存/取消修复继续有效；新增非空 Library Albums/详情/正常刷新/Back 与 Artists 概览已接受。剩余自然来源错误后的手动 Retry、身份匹配且专门同意的 Web Home、其他目录/平台矩阵及非空评论回复；现有评论权限返回 insufficientPermissions。 |
| XW-74 性能 | 获准八次真实位移和 24 次输入边界已通过；私有生命周期脚本的 29 项模拟检查通过。旧录制在末次输入后因覆盖中断提前停止，仍缺正常保存的帧记录、完整 AX 对照和事件/锚点归因；无 FPS、能耗或泄漏改善结论。 |

最新 64 区域映射见 [验收对照](../ui-ux-acceptance-reconciliation.md)。没有新增已批准但完全缺失的产品功能。系统、账号、真实来源和测量前提由现有任务管理，不通过构造来源或扩大权限填补证据。

2026-10-11 本轮已完成 CI 确认、真实磁盘回归、Shortcuts 绑定调查与非空目录原生小节。后续按条件接续：Shortcuts 可研究自有未运行配方的原生导出，在 Run 前读取精确目标；公开导出入口已确认，实际身份可读性和本机账号要求仍未知。Pull 原生预览保留现有只读账号/完整快照前提；Home Retry 只在真实来源错误出现时验收。已完成范围继续复用。

## 协作与证据

源码/构建/测试/Git 与原生阶段互斥；使用独立 namespace、精确 PID/窗口和完成标记。原始 seed 保持 0400，只有自有可丢弃副本设为 0600。停止前的实际数据库核对与恢复后的副本核对分别记录；正常应用、资料、偏好、Keychain 和当前构建保留。

私有证据位于 `~/.muses/tmp/engineering-oct08/round-3/` 与 `round-4/`。完成标记表示阶段结束和清理，必须结合通过字段解释。已归并并可恢复归档的历史/完成对话共 23 个；未完验收的执行对话保留。文档分类见 [工作索引](README.md)。
