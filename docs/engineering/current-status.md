# 当前修复与验收状态

2026-10-14，XW-100 已建立三个独立原版本进程的真实页面重复触发，并完成原生横栏修复的本机复验。最终隔离候选 10021 的两个独立进程均通过 Roselia 页面原生横向来回滚动；临时模式 2 下逐键正向经过全部 17 张卡片、反向从第 12 张回到首张，焦点会带动横栏显露，Space 菜单／Escape、正确专辑打开、重读、重建、Back 和冷启动通过。早先 10019 与 10020 的焦点失败单独保留。974 项 / 132 套件、14 项发布检查、独立磁盘失败重试及 Release／签名通过；CI 与集成以本次修复 PR 为准。模式恢复 0，两个候选与自有设置进程正常退出；正式版 PID 85043、应用摘要和 45 项偏好保持。正常程序此前产生的四条新增记录已保留为 89 条，未回滚；最终前后 27 表／64 项结构及库文件字节一致。后续仍保留完整 VoiceOver、macOS 26、账号与其他验收条件，见 [修复与验证记录](artist-catalog-acceptance.md#xw-100-repair-follow-up-2026-10-14)。

2026-10-14，XW-73 新增限定艺人目录小节：真实 Roselia 24 首歌曲/1 张资料库专辑的详情、在线 8 条曲目、同 PID 正常重读、人工横向滑到两张末端专辑及后续 AX/画面核对、Back 和正常退出已完成。当前响应含 17 个有效唯一专辑身份，初始 15 项 AX/7 张绘制卡片不是完整数量。首 PID 在声明的 AXScrollToBottom 后发生 SwiftUI lazy 辅助功能路径 SIGTRAP，独立追踪为 [XW-100](https://linear.app/xiaotwu/issue/XW-100/muses-investigate-artist-online-shelf-accessibility-scroll-crash)；续跑不覆盖首轮失败，也没有窄源码修复依据。候选资料/队列真值、32 项 seed 偏好保留，自有应用/注册/data/cache/偏好已清理，系统模式 0；正常 45 项偏好与安装摘要保持，正常 27 表中 20 表同值；另 7 表含 3 条新增播放记录（82→85）、一首既有歌的播放计数/时间和队列/会话/ORM 写入，530 项集合与原历史保留，变化未回滚且未由快照推断输入原因。五个简化诊断各一次声明 AX 滚动均成功且正常退出，不能排除真实复杂页面原因或算作修复；原始签名包已按字节核验归档，诊断注册/应用/偏好/临时缓存已清理。此前要求的真实页面可重复触发已在最新修复记录建立，后续仍须修复复验，见 [艺人目录报告](artist-catalog-acceptance.md)。最新 Linear 为 25 项开放（18 In Review、7 In Progress），唯一开放 Bug 为 XW-100；XW-73 保持 In Review。

2026-10-14，XW-99 的 `8560bab` 窄修复已完成本机 Release 编译、独立源码审阅和限定原生复验：临时键盘模式 2 下 Tab 到原信息按钮→Space 打开→Escape 关闭，原焦点/轮廓保留；关闭后 Escape 未破坏继续 Tab 到相邻 Off toggle，Shift-Tab 可返回。原生点击打开后 Escape 也关闭。工具未建立文本选中，用户明确补验“文字已选中，Escape后关闭”；协调方随后回读弹窗缺席、焦点在原按钮，将人类补验与后来回读分开记录。首次 modifier guard 选错 API 重载的 Release 失败（17.516 秒）完整保留，显式 `phases: .down` 的最终编译成功（66.958 秒）。General 已恢复，候选与自有 System Settings 正常退出，系统模式在 UI 恢复 0 并读回 0。独立复核业务期 27 表同值、停止后的七项队列 JSON/用户真值、正常 27 表/45 项偏好及安装摘要均保留，自有 bundle/注册/data/cache/偏好已精确清理，原 0400 seed 保留。[PR #7](https://github.com/xiaotwu/Muses-Polyhymnia/pull/7) 已合并为 `fc339c80d1ecc827e07ed49d8f811c3e20fc70ef`；精确 PR head `639a2771fb6e648c8b49c19d5cee6d82b075abc8` 的 [CI 38653245594](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38653245594) 全阶段通过：968 项 / 130 套件（57.336 秒，常规 Swift Testing 报告，opt-in 跳过项另有边界）、14 项发布配置（5.560 秒）、独立磁盘恢复 1 项 / 1 套件（0.125 秒），Release/App Intents 元数据、签名预览打包和上传均通过。合并执行源码与已验本机/PR 源码一致，XW-99 已 Done；[main CI 38654810970](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38654810970) 已在精确 merge commit `fc339c80d1ecc827e07ed49d8f811c3e20fc70ef` 全阶段成功：968 项 / 130 套件（62.797 秒，按实际常规报告并保留 opt-in 跳过边界）、14 项发布配置（5.798 秒）、独立磁盘恢复 1 项 / 1 套件（0.120 秒），Release/App Intents 元数据、签名预览打包和上传均通过。XW-71 与 XW-75 继续 In Review，完整 VoiceOver、实际 macOS 26、设备矩阵及各自未测状态未增加通过结论。安装的正式 0.6.0 未替换，源码修复待后续正式发版生效。XW-99 合并后的历史检查点为 24 项开放（18 In Review、6 In Progress），当时开放 Bug 标签为零；最新状态见本文顶部，父任务与协调项仍包含在计数中。详见 [信息弹窗 Escape 修复验收](settings-info-escape-acceptance.md)。

2026-10-14，XW-75 的未保存歌曲信息 Title 草稿交接小节已接受：验收执行源码 `f73a673`（与 `e6ae129` 一致）的新签名隔离候选中，一次真实 SearchLyricsIntent 保留同一 Edit Info 和精确草稿；Cancel 后原录音标题 query 无需重发即呈现，Tab 到 Artist、Escape 仅关闭歌词面板。完整框架 XCTest Passed 1/0/exit0，38 文件结果归档核验通过；Intent 前后 27 表同值，停止后的生命周期/JSON 序列化变化单独记录，7 个 decoded queue JSON、会话真值、673 Tracks/82 Events 和两处 60,074.648526 ms 保存位置保留。正常应用 27 表、45 项偏好及安装摘要同值，自有候选/runner/偏好/注册/data/cache 已清理，原 seed 0400 保留。未保存 metadata、Apply 歌词或播放；不增加 provider 匹配、性能、手动 Siri/Shortcuts、macOS 26 或完整 VoiceOver/设备矩阵结论。XW-75 继续 In Review，见 [草稿 Intent 交接](edit-draft-intent-acceptance.md)。

2026-10-14 早先锁屏准备检查点，XW-73 当时只完成准备（后续原生结果见本文顶部）：整个历史真实 Roselia 导入停止检查点按原 SHA/0400 完整复制，24 项关联、队列/会话和当前 439 项执行输入经独立核对。原生入口报告 Mac 锁定，没有取得候选界面状态或运行 PID；未增加艺人详情、在线作品或分页通过结论。准备的自有候选应用、数据/缓存和偏好已清理，注册记录缺席，正常 27 表、45 项偏好与安装摘要保持；真实种子与资格/守卫更正记录保留。接下来须手动解锁，取得新正常基线并重新组装，再实际检查 Open Roselia → 在线曲目 → 正常重读 → Back。该界面没有手动 Load More 按钮，不从历史缓存推导续页成功；不新增账号或系统权限。

2026-10-14 修复前检查点：XW-71 在用户单独授权的临时 Keyboard navigation 2 下完成四个 Help disclosure 的实际 Tab 焦点与 Space 展开/收起。信息按钮已有实际焦点与可见轮廓，Space 打开说明；AX Cancel 关闭且保留原按钮焦点。但原按钮持焦点时后台 Escape 未关闭说明，移到相邻 toggle 后 Escape 才关闭，toggle 未改。用户报告实际前台 Escape 后说明仍在，协调方后来回读已消失；中间未执行关闭，其关闭时间/原因未归因，不把后来消失写成捕获的物理通过或失败。窄修复由 [XW-99](https://linear.app/xiaotwu/issue/XW-99/muses-dismiss-settings-info-popovers-with-escape-from-the-originating) 跟踪，当时 In Progress / Bug，尚未完成实现或修复后验收；后续本机复验与当前状态见本文顶部。系统已在 UI 恢复 0，候选与自有 System Settings 已退出清理；XW-71 继续 In Review。

XW-99 修复前的实时 Linear 检查点为 25 项开放：18 In Review、7 In Progress，唯一开放 Bug 标签为 XW-99；包含阶段验收和协调父项，不能将开放数量解释为独立未修缺陷。旧公共 Home Retry 已退休；已完成的 XW-90–98 仍按原限定范围保留，不删除原失败证据，也不重启 XW-96 的严格 300ms 计时专项。后续任务状态须结合当前修复与远端验证门槛回读。

2026-10-14 新用户范围：[导入署名与封面呈现](credits-and-cover-followup.md)。XW-97 已实现旧 owner 署名的显式预览、来源/元数据核对、原子修复、恢复记录和撤销；XW-98 已实现歌曲/歌单 3:4 焦点卡、多张 Muses 聚焦横栏及低档封面升级且保留 HQ/maxres 优先。本机 968 项 / 130 套件、14 项发布配置、独立磁盘恢复、Release 与隔离原生修复/冷启/撤销及多尺寸视觉验收通过。两项均为 **Done**；[PR #6](https://github.com/xiaotwu/Muses-Polyhymnia/pull/6) 已合并为 `e6ae129`，精确 PR head 的 [CI 38641107802](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38641107802) 全阶段成功，合并 main 的 [CI 38643452573](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38643452573) 亦全阶段成功：968 项 / 130 套件（58.424 秒）、14 项发布配置（8.946 秒）、独立磁盘恢复 1 项 / 1 套件（0.149 秒）、App Intents 元数据、预览打包和上传。合并源码与已验 PR 无差异，收尾仅修改文档。正式 27 表、45 项偏好以及应用 Info.plist/主可执行文件摘要完全保留，现有 0.6.0 尚未获得本节源码；旧署名须在新版本显式预览并应用修复。

2026-10-14 用户验收决定：按人类实际操作接受 XW-96 当前功能，结束本小节并转向其他主要问题，XW-96 **Done**。实际小于300ms的精确输入计时仍未验证，不再阻断后续工作。授权临时系统模式2下的Focus Navigation按钮焦点、Tab移出隐藏、Shift-Tab返回展开与Space激活History均按范围通过；系统已恢复0及General页面，既有真实hover、普通重开与紧凑纯文本滚动结论继续有效。不扩展为模式0按钮焦点或完整设备/VoiceOver矩阵通过。本轮无生产源码变更，详见 [导航验收](now-playing-navigation-acceptance.md)。

[PR #5](https://github.com/xiaotwu/Muses-Polyhymnia/pull/5) 已合并为 `ceb2e295571b89d3bc6a6da11571d0eb526383cf`。精确 head `1e377954` 的 [CI 38514615922](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38514615922) 全阶段成功：944 项 / 129 套件（60.259 秒）、14 项发布检查（5.954 秒）、独立磁盘恢复 1 项 / 1 套件（0.137 秒）、Release、App Intents 元数据和 ad-hoc 签名预览打包/上传。合并 main [CI 38517976309](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38517976309) 也全阶段成功：944 项 / 129 套件（56.394 秒）、14 项发布检查（5.834 秒）、独立磁盘恢复 1 项 / 1 套件（0.126 秒）、Release 元数据、预览打包、签名验证及上传；其源码与已验 head 一致。文档收尾不改变源码、测试或构建配置。已安装的正式 0.6.0 未替换，修复将在下一次正式发版生效。

两轮已授权短录制/观察均结束：首轮封装报错且缺少完整计时输出，第二轮正常保存但封面事件资格未通过，均不证明小于300ms。自有候选进程、录制会话与观察器已结束；候选bundle、独立data/cache/偏好域、helper binary与重编译缓存清理，私有证据保留。候选用户真值未变，内部检查点及最终EQ运行时偏好有变化；正式应用本轮未操作，安装摘要保持，正常资料和更新检查时间的后来变化保留，不回滚或声称整库/全部偏好不变。

前一轮hover审计检查点：候选正常退出、32项seed偏好匹配及4个运行时键保留，Track673整行与seed一致、Events仍78；仅自身4次检查点事务，未进入正式namespace。正式完整45项偏好及应用摘要当时保持；旧播放会话新增completed记录（Events78→79、history15→16）及1:23位置，原历史/530项集合身份顺序/Up Next/Smart Shuffle保留。该检查点不替代新键盘/锁屏小节的数据审计。

以下发布后历史小节保留当时证据与边界；最新 XW-96 结论、候选清理和正式数据审计以上文及剩余条件表为准。

2026-10-13 发布后接续：用户授权实际操作已安装的正式版 0.6.0，并决定彻底移除公共发现，只保留 Muses 与真实账号推荐。XW-75 原含最小化、闭窗、Quick Search、framework 请求与 Now Playing Back 的完整连续路径已通过；真实歌词服务预览及浮窗上方原生弹窗也已接受。正式操作复现的 **XW-90 冷态 Play 无主窗口** 和 **XW-92 主窗口视频截获歌词弹窗键盘** 分别在 `f2ef10f`、`7481961` 修复；**XW-91 公共发现退休** 在 `a30cebd` 实现。三个修复已通过候选原生小节、受控回归和独立复审，[PR #2](https://github.com/xiaotwu/Muses-Polyhymnia/pull/2) 合并为 `9f482a5`，XW-90/91/92 均 Done。详细操作、数据恢复和限定范围见 [正式版检查](post-release-formal-inspection.md)。

本轮 XW-93 已受控确认并窄修复：旧分页不再清掉新同名请求的 loading 标记，完整刷新同步释放旧 loading/error。原始 15 个失败断言和修复后通过均保留，39 项 / 5 套件相关回归及最终独立复审通过；详见 [分页状态归属](home-continuation-ownership.md)。[PR #3](https://github.com/xiaotwu/Muses-Polyhymnia/pull/3) 的完整 [CI 38487746201](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38487746201) 全阶段成功（917 项 / 127 套件、独立磁盘恢复、14 项发布检查、元数据与打包/上传），合并为 `bc7d24e`，XW-93 Done。精确 main `bc7d24e` 的重复 [CI 38489943090](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38489943090) 亦全阶段成功：917 项 / 127 套件（57.108 秒）、独立磁盘恢复 1 项（0.157 秒）、14 项发布检查、元数据与打包/上传。

正式版新增 Queue 上方歌词 Intent 的 Tab/Escape 小节已接受。用户新报告的侧栏问题已按十二个浏览目的地和导入详情的指针封面入口检查，早期宽窗检查未复现稳定故障；普通歌词默认值这次是真实视频标题，但艺人仍是发布者。XW-94 已修复保留来源下的旧 owner 署名和显式重导入；XW-95 已修复真实录音 metadata 的默认查询准备、草稿保护及原生同值写回。定向回归分别为 144 项 / 14 套件和最终 107 项 / 14 套件，独立源码审阅及 XW-95 签名隔离 Release 的默认搜索、编辑、提交、Restore、Escape 小节通过。[PR #4](https://github.com/xiaotwu/Muses-Polyhymnia/pull/4) 已合并为 `377ad48`，XW-94/95 Done；详细证据、初次原生失败和修复后的限定范围见 [输入与署名检查](post-release-input-and-credits.md)。XW-96 的后续 hover 修复及未覆盖条件见本文顶部。

精确 PR head `9264677` 的 [完整 CI 38496218028](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38496218028) 全阶段成功：944 项 / 129 套件（60.655 秒）、14 项发布检查（5.271 秒）、独立真实磁盘错误恢复 1 项 / 1 套件（0.136 秒）、App Intents 元数据、预览打包和上传。合并 main `377ad48` 的源码、测试、构建脚本与该 head 无差异；重复 [main CI 38498051238](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38498051238) 也全阶段成功：944 项 / 129 套件（64.823 秒）、14 项发布检查（5.574 秒）、独立磁盘恢复 1 项 / 1 套件（0.163 秒）、Release 元数据、预览打包、签名验证和上传。PR #4 文档收尾没有改变已验源码；该小节隔离产品、偏好、缓存及自有进程已清理，修复工作树已可恢复归档。安装的 0.6.0 保留，修复将在下一次正式发版生效。

2026-10-13 较早 XW-96 检查点：正式版 Dark 实际 840×804pt 的稳定封面与歌词布局未复现侧栏重叠，随后补齐本份含 48 个非空行的无时间轴纯文本歌词的首段/中段/末段滚动可达、下边界及往返恢复。首屏部分文字被 dock 遮挡，但实际滚动后首末段完整可读；未确认不可读取的故障。全部 27 表完整读取值（含 ORM）、45 项完整偏好及正式应用摘要一致，原 1280×804pt、暂停及集合上下文恢复；自有原生会话/客户端已结束，正式应用保留。用户选择先完成其余三项，又在桌面继续争用时选择先做不争用桌面的检查；真实 hover/focus 和退出过渡内快速重开尚未接受，没有录制或源码/测试变更。具体结果与接续前提见 [导航剩余验收](now-playing-navigation-acceptance.md)。

2026-10-13 的 Linear 检查点记录 25 项开放：18 项 In Review、7 项 In Progress、0 项 Backlog，包含父任务及协调项。「Bug 标签开放为零」只属于该历史检查点；后续真实 hover 失败曾确认，XW-96 当时转为 In Progress / Bug，完整产品矩阵没有全部完成。XW-75 仍 In Review；真实 macOS 26、手动 Siri/Shortcuts 和完整 VoiceOver 矩阵没有新增通过结论。旧公共 Home Retry 要求退休，不计为通过。

2026-10-13 工具诊断检查点：用户随后释放桌面控制。当时前台诊断确认：安装 cua-driver 0.28.1 的 desktop move 只 warp 指针，不生成悬停事件，故未显示导航不能归因于应用 hover 故障。原生 Computer Use 菜单与 Tab 没有取得导航按钮焦点，系统键盘导航只读值为 0；Command-[ 确实返回原 Liked 详情。全局焦点快捷键被 QQ 拦截，新迷你窗口已关闭。当时请求真实指针和菜单/Tab 人工核验并暂停 GUI 输入；正常 Muses 当时有意保留在 Now Playing，原尺寸和暂停上下文保留，最终浏览/指针/前台恢复待人工小节结束。检查点的全部 27 表、45 项偏好与应用摘要一致；自有 driver 会话/客户端结束，没有源码、测试、录制或构建变更。工具诊断小节完成，XW-96 仍未完成，细节见 [导航验收](now-playing-navigation-acceptance.md)。该工具检查点回读完整 main CI 38498051238 为 success。

更早的本机检查点：912 项 / 126 套件 Swift 报告通过（27.877 秒，包含 opt-in 跳过项），14 项发布配置检查、独立磁盘恢复 1 项 / 1 套件、Release 编译与新 App Intents 元数据通过。候选冷 Play 在 Cua 读取前已记录到主窗口，新进程正确曲目推进/Pause；视频歌词 Tab/Escape、视频/章节/评论自身关闭以及 Home/New 两来源空态均通过。正式版、资料与凭据保留，该小节全部自有候选已清理。

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

## 已接受的原生结果（历史小节）

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
| XW-97 旧导入署名 | Done；显式、可恢复修复已完成，本机完整回归、隔离 655 项 Apply/冷启/Undo 通过；PR #6 已合并，PR 与 main CI 均成功，正式资料未写入，待新版本显式应用。 |
| XW-98 封面呈现 | Done；焦点卡比例/宽度、多推荐聚焦横栏和低档封面升级已完成；实际三尺寸及 Large 深色、原生横栏滚动通过，PR #6 已合并，PR 与 main CI 均成功。 |
| XW-75 App Intents | 冷态歌词、完整串行键盘、真实来源预览/浮窗弹窗、修复后的冷 Play 与主窗视频弹窗，以及本轮未保存 Edit Info Title 草稿→一次外部请求→Cancel→原 query→Tab→Escape 已按记录范围接受。完整 Passed 1/0/exit0 及恢复清理见 [草稿交接](edit-draft-intent-acceptance.md)。其他未测呈现状态、手动 Siri/Shortcuts、实际 macOS 26 与完整 VoiceOver/设备矩阵仍保留；XW-75 继续 In Review。 |
| XW-26 Pull/播放父项 | XW-84 的原生错误与同草稿重试已关闭，见 [原生恢复](pull-native-recovery.md)。父项保留真实评论/回复、其它来源/视频和未测持久化分支；自然远端冲突、Push/manage 与破坏性历史/group 保持原排除范围。 |
| XW-71 Settings | 十类设置/历史、字体指针/键盘、语言/字号恢复和 Dark 840×804 三项检查已接受。本轮临时模式 2 下四个 Help disclosure Tab/Space、信息 AX Cancel/原焦点及修复后的原按钮 Escape、继续 Tab、点击打开与人类文本选中 Escape 按范围通过；系统恢复 0，保护/清理独立复审通过。XW-99 已 Done，PR #7 已合并且精确 PR/main CI 全阶段通过；完整 VoiceOver、实际 macOS 26 与其他设备/焦点条件仍保留，XW-71 继续 In Review。 |
| XW-99 信息弹窗 Escape | Done；`8560bab` 本机 Release、独立源码审阅、限定原生复验与完整保护/清理复审通过。[PR #7](https://github.com/xiaotwu/Muses-Polyhymnia/pull/7) 已合并 `fc339c8`，精确 PR head `639a277` 的 [PR CI 38653245594](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38653245594) 和精确合并提交的 [main CI 38654810970](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38654810970) 全阶段成功，执行源码一致。原始人类前台失败报告、后台路径、后来无归因消失及首次编译失败保留；见 [验收报告](settings-info-escape-acceptance.md)。 |
| XW-72 辅助窗口 | MiniPlayer 生命周期/Pin/共享播放、真实同步桌面歌词和菜单栏 Escape/音量已接受。剩余物理控件交接/完整焦点、真实未同步歌词、系统 Dark 菜单栏。 |
| XW-73 来源、XW-62 评论 | 既有两来源、缓存/取消边界与 Albums 小节继续有效，旧公共 Home Retry 退休。本轮艺人详情、在线正常重读、人工横向末端/后读及 Back/退出按 [艺人目录报告](artist-catalog-acceptance.md) 的限定范围记录；首轮 AX 崩溃单独追踪。剩余真实专门同意且身份匹配的 Web Home、其他目录/播放/错误与平台矩阵、实际 provider continuation 及非空评论回复；评论权限仍 insufficientPermissions。 |
| XW-100 艺人专辑 AX 滚动 | 最终 10021 本机真实页面／冷启动 AX 来回与 17 卡键盘焦点显露通过，菜单及正确专辑打开保留；974 项／132 套件、Release／签名与发布检查通过。原版本三次崩溃、七个窄失败及两次焦点失败独立保留；修复 PR 的检查和集成完成后再恢复其他验收。完整 VoiceOver 与 macOS 26 未覆盖。 |
| XW-93 加载标记归属 | Done；两条受控状态缺陷已修复，39 项 / 5 套件回归、独立复审和完整 CI 通过，PR #3 已集成。不增加原生、真实 Web 来源或旧内容泄漏结论。 |
| XW-94/95 署名和歌词默认查询 | Done；原始失败、144/107 项定向回归、独立复审、签名隔离版歌词输入小节及 PR #4 完整 CI 通过。保留 UUID、手工 metadata、录音版本和显式 query；不猜测永久删除后的来源，不把数字验收参数或 37 个手动查询候选称为当前录音自动匹配成功。真实换账号重导入没有新增原生结论。 |
| XW-96 间歇侧栏 | Done；用户根据实际人类操作接受当前功能并要求转主要问题。两文件修复、真实hover、普通重开、临时模式2焦点路径和既有紧凑滚动按范围通过，系统已恢复0；PR #5与main完整CI通过。严格小于300ms计时未验证且不再阻断；其他系统/外观/辅助功能覆盖归父级矩阵。测试产品已清理，见 [导航验收](now-playing-navigation-acceptance.md)。 |
| XW-74 性能 | 获准八次真实位移和 24 次输入边界已通过；私有生命周期脚本的 29 项模拟检查通过。旧录制在末次输入后因覆盖中断提前停止，仍缺正常保存的帧记录、完整 AX 对照和事件/锚点归因；无 FPS、能耗或泄漏改善结论。 |

最新 64 区域映射见 [验收对照](../ui-ux-acceptance-reconciliation.md)。没有新增已批准但完全缺失的产品功能。系统、账号、真实来源和测量前提由现有任务管理，不通过构造来源或扩大权限填补证据。

2026-10-12 本轮完成 XW-84 原生恢复、XW-75 歌词冷启动，以及新发现 XW-89 的完整修复/复验小节。0.6.0 发布后先处理 XW-75 原含关窗、Quick Search、framework 请求和歌词关闭的串行键盘路径，再按已具备条件的剩余呈现状态推进。这一旧公共 Home Retry 顺序已由 2026-10-13 用户的功能退休决定取代；已完成且仍有效范围继续复用。

## 协作与证据

源码/构建/测试/Git 与原生阶段互斥；使用独立 namespace、精确 PID/窗口和完成标记。原始 seed 保持 0400，只有自有可丢弃副本设为 0600。停止前的实际数据库核对与恢复后的副本核对分别记录；正常应用、资料、偏好、Keychain 和当前构建保留。

私有证据位于 `~/.muses/tmp/engineering-oct08/round-3/`、`round-4/` 与 `round-5/`。完成标记表示阶段结束和清理，必须结合通过字段解释。已归并并可恢复归档的历史/完成对话共 23 个；未完验收的执行对话保留。文档分类见 [工作索引](README.md)。
