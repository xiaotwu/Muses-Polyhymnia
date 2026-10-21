# 功能实现与补充验收

2026-10-20 当前用户决定：XW-62 已[完整移除评论与回复](comments-retirement-acceptance.md)，包括查看入口和读取请求；旧非空评论／分页和 `insufficientPermissions` 验收条件退休，历史证据保留。移除后的实际视频／章节行为按报告接受，不计为旧评论功能验收通过。另补验[目录冷重开](catalog-cold-reopen-acceptance.md)，并修复实际发现的 [XW-104 繁体设置文案](settings-traditional-chinese-acceptance.md)。用户确认触控板正常并跳过后续测量；[性能基线仍不完整](scrolling-native-input-followup-oct20.md)，没有据此优化应用。

2026-10-20 接续：[快捷指令来源与手动运行](manual-shortcuts-acceptance.md) 已接受两类动作的精确来源、歌词三类窗口、真实 Play 冷启动／Pause 和无效链接错误／OK。Siri、其他配置及系统／设备条件继续保留；产品源码未改，当前范围仍以 [统一核对记录](current-status.md) 为准。

2026-10-13 更新：用户授权的正式版检查已补齐 XW-75 原完整串行窗口/键盘路径、真实歌词预览与浮窗弹窗交互；确认 XW-90 冷态 Play 窗口和 XW-92 主窗口视频键盘缺陷。用户另行退休公共发现，由 XW-91 执行；下文旧匿名 Home/自然公共错误 Retry 范围不再作为待办，真实账号、目录及系统条件继续保留。当前范围见 [正式版检查](post-release-formal-inspection.md)。

已归并对话没有提供新的、批准但完全未实现的产品功能。现有 YouTube 音乐/播客、目录、队列、歌词、视频、Settings 与更新已在源码中实现；当前待办主要是状态分支和原生验收。发现实际缺口后才创建具体实现任务，避免把未测状态写成未实现功能。

当前状态以 [统一核对记录](current-status.md) 为准。2026-10-10，XW-79 的草稿、历史及真实 506 项尾曲自然停止/循环验收已经完成；本页仅规划其余具体条件，不重做已接受流程。

## 执行任务与剩余条件

| Linear | 范围与结果要求 | 实现边界 |
| --- | --- | --- |
| XW-71，父 XW-25 | 完整 VoiceOver、实际 macOS 26 及其余未覆盖配置；十类分类/历史、字体指针与 Up/Down/Return/取消、样本及语言/字号恢复，以及四项 Help 的 Tab/Space、信息弹窗原按钮焦点和 Escape 已接受 | [XW-99 原生结果](settings-info-escape-acceptance.md) 包含真人文字选择后 Escape；临时键盘导航已恢复 0，不把历史 Help/焦点待办重复列为当前缺口 |
| XW-72，父 XW-25 | 物理控件交接/完整焦点、真实未同步歌词、系统 Dark 菜单栏及其余外部矩阵；生命周期/Pin/快捷键、共享音量及真实同步桌面歌词已经接受 | 保持同一 PlaybackService。两首既有 test 录音的有界只读查找未找到真实未同步文档，不剥除时间戳或扩大整库查询 |
| XW-73，父 XW-19 | 当前候选成功身份匹配的 Web Home及其余来源/平台矩阵；非空 Library Albums/详情/正常刷新/Back、Artists 详情/在线重读，以及限定在线专辑 Play/Next/Previous 已补验 | [真实作品播放小节](artist-release-playback-acceptance.md) 核对本次响应 24 项身份/顺序与预期候选写入；其他播放分支仍保留。公共 Home 与其错误 Retry 条件已退休。[24 首真实来源导入与目录验收](library-catalog-acceptance.md) 保留稳定身份和原库真值；不把正常刷新当作错误 Retry 或完整 loading/外观矩阵 |
| XW-75，父 XW-25，In Review | 冷态歌词、完整串行窗口/键盘、真实歌词预览/浮窗弹窗、修复后的冷态 Play 和主窗视频弹窗已按限定范围通过；两动作来源及五项原生 Shortcuts Run 已按报告接受；继续其它未测呈现、Siri、其他 Shortcuts 配置和系统/设备矩阵 | 精确 bundle 的真实 AppIntentsTesting 证据见 [交接报告](app-intents-handoff.md) 与 [正式版检查](post-release-formal-inspection.md)；不将框架调用当作手动 Siri 或 macOS 26 图形验收 |

每个任务记录实际源码、系统、窗口、数据来源、指针/键盘/菜单结果和残留边界。新发现的可复现缺陷单列子任务，维持小范围修复。已有 XW-17/15/8/18 等阶段任务保持 In Review，协调任务保持未完成，直到对应验收门槛满足。

2026-10-10 解锁后已完成 XW-19/25 的三个新视觉子集：Dark / 840×804 / Standard 与 Large 下，Avenir 待确认轮廓、Classic 已选勾选、搜索焦点及三个角色样本均完整；Dark / compact / Large Help 的账号访问和播放缓存说明展开、完整滚动阅读与收起通过。完整原生弹窗画面在保持窗口尺寸、置于屏幕右缘后取得；初始父窗口捕获边界不是应用裁切证据。未扩张前台控制或改变 OS 设置，恢复清理已核验。具体证据见 [Settings 视觉跟进](settings-focus-followup.md)，既有键盘功能与外部焦点/VoiceOver/macOS 26 条件继续按原范围记录。

## 继续沿用既有任务

| 现有任务 | 待验范围 | 不得推断的结论 |
| --- | --- | --- |
| XW-26、XW-13、XW-16 | 已有队列/草稿/历史和 XW-79 尾曲通过项之外的真实来源/Pull、持久化失败、外部及未授权的破坏性分支 | 不为验收便利简化成熟工作流；不把未授权分支当作当前执行指令，不操作 Liked 或远端 Push |
| XW-14、XW-15 | 歌词来源/翻译/艺术图对比、视频/EQ/辅助状态 | 没有真实时间轴不能发明歌词同步；网页视频不是音频引擎 |
| XW-62 | 完整移除视频评论／回复的入口、面板、浏览器、读取 API 与专属模型；复验视频关闭和章节等保留行为 | 用户已退休评论功能；旧非空分页及权限限制保留为历史，不扩张授权、不迁移正常资料库 |
| XW-18 | 当前候选在现有授权下成功且身份匹配的 Personalized Home、真实恢复分支；历史 XW-20 仅保留当时范围 | 单独明确同意、固定浏览器来源、helper IPC 和临时 jar 边界继续生效 |
| XW-6、XW-7、XW-25 | 实际 macOS 26 原生运行及尚缺的导航/辅助功能状态 | CI 的 macos-26 编译不证明完整图形交互；用户延期的 OS 矩阵仍未通过 |
| XW-8、XW-26 | 已授权且有内容的订阅频道/Shorts/分页 | 当前频道空订阅不能证明非空状态；不修改真实账号订阅来制造样本 |

## 已实现而不重复规划的功能

当前合同保留独立 Albums/Artists、Track-backed Music Videos、主窗口 Search、原生导航与十类 Settings、浮动 PlayerBar、完整 Queue、封面/黑胶/歌词、按需视频、播客进度和 Sparkle 更新。项目改名、已发布版本及已修复菜单/署名不重新进入 Feature 待办。旧 macOS 14 说明、旧页面/菜单设计和已过时发布清单是历史证据，当前 macOS 26 与产品合同优先。

补查早期方案后，以下差异已单独核对：`CatalogTrackReleaseMembership` 与目录投影已有稳定多发行关联，不重复创建旧 R002 的“缺失实现”；完整播客与 Shorts 已有实现，旧 R014/R015 的缺失说明不是当前状态。只读回复属于已退休的历史功能。官方播放器字幕/画质与原生悬浮视频继续按既有边界运行，不增设无效分辨率或通用 DRM/WebKit 音频路径。当前语言是英语、简体中文、繁体中文及系统跟随；早期十七语言提案没有当作当前完成或新增实施授权。

早期对话提出重启恢复最后浏览页面；`ef8730e` 后 `RootView.handleAppear` 明确从 Home 初始化，当前实际冷启证据也是 Home。保留这一冲突的历史来源与当前行为，不把旧方案直接恢复为功能任务。Settings 别名/深链接和窗口内 Back/Forward 的验证仍属于 XW-69/71。队列与播放位置的暂停恢复另属已实现播放合同；睡眠唤醒、真实设备断开等缺少条件的验收保留在 XW-26 的边界，不自动触发系统操作。

Radio、本地扫描/音频文件导入/M3U/Add Local、长期迁移 capsule 继续退出产品。没有新的用户决定时不重建仓库、改写历史、安装/发布或提高账号权限。

## 修复后的剩余验收

执行源码 `03b8a1e` 的 [完整 macOS CI 38116679660](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38116679660) 全阶段通过：895 项测试、123 个套件（45.849 秒），8 项发布配置检查，以及 App Intents 元数据、预览打包和上传。

XW-83 的失败曲目重试、XW-85 的保留投影刷新和 XW-86 的 Intent API 修复已关闭。XW-85 在实际导入歌单和固定 Library query 中完成四次 Save、六个数据库检查点及原值恢复；最终业务 test case Passed，整体 xcresult 因后续 runner 取消为 Failed，具体证据见 [修复报告](remaining-review-fixes.md)。普通 Playlist 的保留详情补验见下；其余完整矩阵仍属父任务。XW-84 已补齐 [真实磁盘写入错误 778 的回滚与重试](pull-disk-recovery.md)，以及 [原生空间耗尽错误、排序草稿保留、同面板按钮重试与冷重开](pull-native-recovery.md)，现为 Done。自然冲突按钮和远端 Push 不在本次原生接受范围。

`03b8a1e` 的新可写隔离副本已接受三个真实框架单元：最小化后同一窗口/PID 恢复、关窗后同一 PID 重建主窗口，以及 Quick Search 原草稿保留、关闭后首次歌词请求正确呈现。Now Playing 上的正确 query 与歌词面板关闭也已观察。后续正常启动的 Cua 对照确认基础 Command-[、真实 View→Back，以及从可见 Match Lyrics 入口关闭面板后的 Command-[ 均退出 Now Playing、恢复 PlayerBar，且仍暂停、音量 0%。该对照没有重放原先包含关窗、Quick Search 和 framework 请求的完整串行路径，因此保留 XCTest 超时，不称整轮通过。实例在前台离开后按精确 PID 合作退出；协调方独立核对 8 项保护哈希一致、原始 seed 仍为 0400、自有进程为零，且隔离产品、数据、偏好和 runner 容器均已移除。27 表审计保留 ORM/会话时戳变化及既有恢复路径填入的 9 个 historyRecordID，不声称所有持久化字节不变。

停止目标的歌词 Intent 冷启与 XW-89 的退出位置保留已通过，见 [新报告](cold-start-recovery.md)。剩余冷态 Play Intent；原含关窗、Quick Search、framework 请求及关闭歌词后的完整串行键盘路径；视频与其他未测呈现状态；手动 Siri/Shortcuts、实际 macOS 26 及完整 VoiceOver/设备矩阵。空链接 import 与图库歌词单元已按各自范围接受。

XW-87：`03b8a1e` 已推送，Debug、Release、26 项既有回归和完整 CI 通过。实际 Library 查询 `1000` 读到 1112×68pt 歌曲行“1000日間, noa - Topic”，时长值“—”；独立视频按钮为“Play in floating video window 1000日間”，值为空、28×28pt、enabled 且 hittable。协调方独立核对两者标签和值不再串用，未激活歌曲或视频。私有测试原先把 seed 上传者当作预期显示艺术家，导致断言失败；源码使用 SongCreditCache 的解析署名，这不是标签修复失败。整段测试与清理结果另行记录，不据此宣称完整 VoiceOver 通过。

## 2026-10-11 补充原生结果

XW-88 已完成。图库上方的歌词面板原先继承了背景禁用状态；`3b44632` 将禁用和辅助功能隐藏限于背景内容。修复后的真实 framework query、输入框可用及 Close、同一歌曲图库保留、背景 AX 隔离、Done 返回和正常 Command-Q 退出均通过；完整 XCTest Passed 1/0（15.09 秒）。协调方独立复核四张窗口图、停止后的 SQLite、八项保护哈希和精确清理。空链接 import overlay 的歌词交接也已接受，但该旧轮退出失败且没有重置前的 import 数据库检查点，保留这两个限制。详见 [图库歌词修复](gallery-lyrics-acceptance.md)。

普通 Playlist 的独立小节已通过：新建并追加两首既有曲目、核对实际身份/顺序、在保留详情中保存标题并即时刷新、恢复原标题，以及按两项预览删除自有歌单。Cua 操作完成两次 Save；协调方独立核对七个 SQLite 检查点，655 首 Track、60 条播放事件及原有集合真值保留。前三次私有测试失败和其中一次实际播放副作用单独保留，本轮不借用 XCTest 通过结论。详见 [普通歌单验收](ordinary-playlist-metadata.md)。

测试与 CI 提交 `8a58f7b` 的 [完整 macOS CI 38149867942](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38149867942) 全阶段通过：常规运行报告 896 项测试、123 个套件（53.867 秒），独立磁盘用例在其中跳过后另以 1 项/1 套件通过（0.144 秒）；8 项发布配置检查、App Intents 元数据、预览打包和上传均通过。应用执行源码仍为 `3b44632`。

2026-10-12：`8877bee` 的停止目标歌词 Intent 复验完整 XCTest Passed 1/0（4.727 秒），两处保存位置仍为 20,000 ms，完整标量/JSON 和资料审计通过；隔离实例已清理。此前 `3b44632` 的冷启交付通过但位置清零，失败证据单独保留。最新 CI 与任务状态以 [当前状态](current-status.md) 为准。
