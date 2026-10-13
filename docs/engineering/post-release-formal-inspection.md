# 发布后正式版检查与修复

2026-10-13，用户授权实际操作已安装的正式版 Muses，继续 XW-75，并明确移除公共发现。检查对象为 `/Applications/Muses.app`，签名版 0.6.0 / build 20261012.1，macOS 27.0.1 / arm64。正式应用没有被重签或替换；源码修改在独立 managed worktree 中进行。

## XW-75 已接受的小节

使用无应用 host 的独立 XCTest runner，通过公开 AppIntentsTesting 按 `com.muses.app` 和正式应用路径绑定。每个请求只调用一次 `run()`；UI 操作和验收由 Cua 顺序执行。框架返回只证明交付，另行核对实际字段、焦点、窗口及播放状态。

| 顺序 | 原生操作和实际结果 |
| --- | --- |
| 最小化 | 原主窗口 67851 在请求前不在屏幕上，请求后同 PID 73474、同窗口恢复；正确 query 和 Close 可操作。 |
| 闭窗 | Command-W 后不使用会重新开窗的观察器；调用前六次观察均没有主窗口，调用后同 PID 重建窗口 67892。正确 query 和 Close 可操作。 |
| Quick Search | 唯一数字草稿保持原值；一次歌词请求等待。关闭 Quick Search 后，该原始歌词 query 出现，没有重发。 |
| Now Playing | 正确歌词 query、Close 和随后的 Command-[ 依次通过，恢复浏览与 PlayerBar，原曲仍暂停，音量 50%。 |

这次连续路径补齐此前超时而未归因的串行验收。四个独立 one-shot XCTest 均 exit 0；不是用正常启动的独立 Back 对照替代原流程。早期 `serial-minimized` 命令参数失败与闭窗后的观察器重新开窗保留为无效/受污染探测，不计入接受证据。

视频浮窗上方的 SearchLyricsIntent 返回真实 LRCLIB `Anti-Hero` 候选，可预览逐行同步内容；没有点击 Use Lyrics 或改写歌曲关联。Tab 进入艺人字段，Escape 关闭歌词弹窗，同一浮窗仍在。该小节接受真实来源内容与浮窗的原生弹窗交互，不代表完整歌词/VoiceOver 矩阵。

## XW-90：冷态 Play 没有主窗口

正常 Command-Q 后，六次目标进程为零的观察先于唯一一次 PlayYouTubeLinkIntent 调用。框架在 22:01:43.410Z 开始、22:01:47.318Z 返回，创建精确正式路径的新 PID 85043。`optionAll` CoreGraphics 清单只有 39pt 高的菜单栏窗口，没有主窗口；Cua 绑定及正常 Finder 重新打开未恢复它。

3 秒只读 sample 的主线程 2281/2282 次采样位于正常 AppKit 事件循环，音频线程有实际 AVFAudio 回调。没有主线程播放死锁证据。用户亲自使用 File → Main Window 后，主窗口出现，原曲实际推进 2:40→2:41；Pause 生效，随后恢复原先 26.6666 秒暂停位置。手动恢复不能追认冷态窗口显示通过。框架的后台启动方式仍是限定条件，未据此声称 Siri 或 Shortcuts 同样失败。

源码中的窗口 factory 原先仅由 `MiniPlayerOpener.onAppear` 提供，无窗口时 Play 的展示请求会丢失。修复保留请求至实际主窗口配置，并从无需 RootView 出现的 scene Commands 安装现有 `openWindow` action；重复请求合并，已有窗口仍通过原入口展示。候选须在真实停止目标调用中无需手动恢复即显示主窗口，才能关闭这项任务。

## XW-92：背景视频截获弹窗键盘

把同一浮动视频返回主窗口后，再调用一次 SearchLyricsIntent。歌词弹窗中 Tab 未离开 query；Escape 留下弹窗。点击其原生 Close 后，背景已回到浏览/PlayerBar，证明 Escape 实际关闭了视频。

`YouTubeVideoStage` 的应用级 keyDown monitor 没有窗口、sheet 或文本输入归属检查。修复让 monitor 和 onExitCommand 只处理当前主窗口内容所属的事件，并向原生 sheet、其它窗口和文本输入让出。章节、评论和正常视频关闭仍须保持原义；候选原生复验须验证弹窗 Tab/Escape 后同一视频仍在，再验证视频自身的 Escape/Close。

## XW-91：公共发现退休

当前用户决定优先于旧匿名 Home 规格：Home 仅提供 Muses 推荐和真实账号推荐。匿名 Home transport、公共来源及错误 fallback、旧公共缓存读取，以及 New 中由订阅标题公开搜索或匿名 RD mix 生成的推荐栏均退休。显式 Search、公开目录和既有 Smart Shuffle 保留；不把公开结果改标为本机或账号来源。

真实账号 Web Home 继续使用专门 consent、固定签名 helper、精确 OAuth channel 匹配、临时权限受限 cookie jar 和规范化分区缓存。无账号、未同意、关闭或失败均显示真实状态，Muses 推荐可独立选择。缺失、未知或退休来源的旧缓存 fail closed；关闭/退出/换账号后，迟到请求和已保存 Web 不得复活。

正式版当前公共来源曾显示隐藏账号快照的“已保存个性化内容”提示，该来源混淆纳入退休变更。旧公共 Home 的自然错误/手动 Retry 待验收项退休，不标为通过。XW-73 的真实账号、目录、集合及平台条件继续保留。

## 数据、恢复与证据

检查前后各做在线只读 SQLite backup，未把旧 backup 覆盖到正式库。所有歌单/导入项、同步/修订、笔记/书签、播客关注及 membership 表读取值一致；673 首歌曲的身份、收藏、资料库标记和歌词真值一致。实际冷播放新增两条聆听事件，ORM 事务也增加，单独记录，不能声称所有库字节不变。

最终恢复原有导入歌单第 122/530 首焦点、暂停 26.6666 秒、50% 音量、单曲循环/关闭随机。临时 Quick Search 草稿清空，歌词与视频关闭，本轮创建的 Finder Applications 窗口关闭；正式应用继续保留。Info/executable SHA-256 前后相同。没有远端写入或 Keychain、系统权限修改。

私有证据：`~/.muses/tmp/engineering-oct13/formal-inspection-3a94730c270e/`（前后实际库、窄观察、sample 与恢复 receipt）和 `xw75-formal-runner/requests/`（每个唯一请求、完整 log/xcresult）。修复候选、测试和清理结果另行补录。XW-75 仍 In Review；实际 macOS 26、手动 Siri/Shortcuts、完整 VoiceOver/设备矩阵及其它未测呈现状态保持未接受。

## 修复候选完成的小节

三个独立实现提交为 `a30cebd`（XW-91）、`f2ef10f`（XW-90）和 `7481961`（XW-92）。
最终源码通过完整 Swift 报告 **912 项 / 126 套件**（27.877 秒，包含 opt-in 跳过项）、
14 项发布配置检查、独立真实磁盘恢复 1 项 / 1 套件（0.049 秒）、
Release 编译（81.24 秒）及新 App Intents 元数据提取。
窗口/视频 23 项和 Home 148 项定向回归与独立源码复审也通过。
最初的旧 public fixture 编译失败和临时目录别名导致的 5 项 cleanup 失败保留；修正后回归通过。

使用全新 `com.muses.acceptance.postrelease-oct13`、同团队签名候选和独立资料副本。
首次 cold-play1 请求返回 metadata error 400 / exit 65：新身份尚未进入系统 App Intents 索引，目标未启动。
该失败保留。通过 Cua 完成一次普通首次启动及 Command-Q 后，cold-play2 在六次零进程确认后只调用一次 run。
新 PID 88805 的主窗口 68222、1260×792pt、onscreen=true，已在任何 Cua/AX 读取之前由被动清单记录。
没有使用 File 菜单恢复；实际正确曲目从 0:35 推进到 0:41，Pause 生效。
使用既有当前曲目缓存，接受冷窗口和播放交付，不新增首次网络解析成功结论。

主窗口视频上方的一次 docked-sheet1 query 为 921130060。
Tab 从歌名字段 165 进入艺人字段 166；Escape 只关闭歌词 sheet，背景原视频保留。
随后视频自身 Escape 恢复浏览，章节 Escape 只关闭章节，未连接账号的评论 Escape 只关闭评论，视频 Close 正常恢复浏览。
未 Apply 歌词或播放视频。

实际渲染与 AX 确认 Home 菜单仅有 Muses 和真实账号两种来源。
本机推荐与导入歌单仍可见；未连接账号时显示 Connect YouTube 和独立 browser consent 说明，切回 Muses 恢复非空本机推荐。
New 保留资料库重发现，账号来源是诚实的未连接空态，没有自动公开搜索或 RD mix。
没有连接候选账号；身份匹配的真实 Web Home 成功仍归 XW-73，未由 fake 测试或空态替代。

正常退出后、任何恢复或删除前保存实际 stopped.sqlite。
673 首歌曲、78 条已有事件保留；受保护集合/同步/笔记/书签/播客表及歌曲身份/收藏/资料库/歌词真值一致。
七个 queue JSON 字段语义一致；当前位置恢复为 26,666.64399092971 ms、index 121、单曲循环、关闭随机。
候选保持初始静音和 Muses 来源并退出；正式版重新核对原 Liked122/530、暂停0:27、50%。
两份完整 xcresult 归档保留 9 个正式版及 3 个候选结果，包括失败。
自有候选、runner 产品、注册、偏好、数据/缓存及诊断 module cache 已按精确路径清理；正式版 Info/executable 哈希一致。

候选证据在 `~/.muses/tmp/engineering-oct13/postrelease-candidate/` 与 `postrelease-candidate-runner/`；
源与测试日志在同级 `xw90-source/` 和完整 Swift、Release、元数据、磁盘日志。
GitHub CI 与合并结果由 [当前状态](current-status.md) 接续。

## 下一步边界

XW-75 已补齐本轮框架串行路径、冷 Play 和主窗口视频歌词键盘小节。
其它未测呈现、手动 Siri/Shortcuts、实际 macOS 26 和完整 VoiceOver/设备条件继续保留。
XW-73 的真实账号 Web Home、目录错误恢复和来源矩阵仍待各自前提。

独立源码审阅发现此前已有的 shelf continuation loading 标记竞争候选：
旧任务被拒绝时可能清除新同名任务的 loading 标记，旧内容仍被禁止发布。
该项未做暂停 continuation 的独立复现，已作为 XW-93 Backlog 单独规划，不在本轮加入无关改动。
