# 播放重试、Pull 事务、编辑刷新与搜索动作标签

2026-10-10 在既有剩余验收中审阅并修复 XW-83/84/85。三项代码分别提交为 `c49818a`、`5fe7487`、`c84d55c`；随后 `8475d31` 包含独立的 [App Intents 交接修复](app-intents-handoff.md)。保留正常应用、原始资料与共享服务身份，没有远端写入或产品权限扩展。

## XW-83：当前曲目失败后的 Play 重试

流地址解析失败后，当前曲目仍然存在。此前共享 `PlaybackService.play()` 直接让已失败的 engine 执行 Play，未重新加载曲目，可能显示正在播放而没有实际开始。现在，在已有暂停/缓冲/正在播放判断之后，如果当前状态仍有错误，就复用已有 `scheduleLoad` 重新加载同一曲目。该入口也覆盖同一首外部链接的重试。

回归先证实两个参数场景中的十处失败：共享 Play 和外部链接入口都没有实际重载。修复后连续失败、再次失败和成功恢复分别核对加载次数、未提前开始播放、曲目与 queue occurrence 身份、Up Next、集合顺序和历史不变。相关四个套件共 23 项测试通过。该修复的完整 [CI 38079546122](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38079546122) 通过 887 项测试、120 个套件及元数据和预览打包。XW-83 已关闭；这些是假 engine 行为回归，不宣称新的原生系统媒体重试验收。

## XW-84：Pull 保存失败保留草稿并原子提交

原 Pull 预览在父视图捕获错误后仍无条件关闭，导致已解决的冲突草稿丢失。服务先保存 Local/Base，再进行可能抛错的修订剪枝；第二次保存失败时会报告整体失败，却已提交部分变更，重试相同预览还可能因基线变化被拒绝。

现在 `PlaylistPullPreviewSheet` 接收可抛错的 Apply，将错误显示在预览内，仅成功后关闭。服务在关闭 autosave 的 fresh context 中一起准备 beforePull、Local、Base、lastSyncedAt 与修订剪枝，再执行一次保存；准备或保存失败时回滚，不发布刷新通知。其他修订剪枝调用保持原有行为。

使用真实内存 SwiftData 模型和仅限 Pull 保存的注入接口，先复现两项测试中的四个问题，再验证失败后的全部 truth/revision/新 Track、通知和同一预览重试。成功路径将 63 条修订裁剪为 50 条且只保存一次；失败不泄漏新数据，原预览能够恢复。15 项定向测试通过，并再次包含在最终 37 项、七套件的来源回归中。该测试是受控的保存抛错，不能代替真实磁盘 I/O 故障或原生错误展示。

2026-10-11 只读复核进一步限定来源证据：[既有失败](playlist-flow-followup.md) 是 cookie-free yt-dlp 导入返回 “The playlist does not exist”，不能推广为已认证 Data API Pull 不可用。生产 Pull Preview 需要已连接且可读取的账号、匹配身份和完整远端快照；seed 虽保留各 506 项、11 页的 Base/RemoteShadow，生产 UI 没有直接用这些历史快照打开预览的入口。此前 Guest、空 OAuth client 和仅选 `test` 是隔离测试选择。当前没有真实 Apply 或底层磁盘保存错误；导入错误、表单校验和受控抛错分别保留原有范围，不代替这两项条件。

## XW-85：已打开歌单与本地搜索即时刷新

Edit Info 成功会增加 `LibraryService.metadataRevision`，但普通及导入歌单详情保留旧的值投影；Search 同样保留旧歌曲匹配和笔记摘要。现在两个详情拥有者观察 metadata revision 并重建本地行值；Search 在 metadata revision、Notes revision 和再次出现时只重投影当前 query 的本地结果。

远端请求、已加载结果、分页前缀、query 和当前 catalog detail 不因本地编辑重启或清空。新测试先复现四处过时搜索断言，再验证歌曲匹配变更、笔记删除/新匹配、20 条远端结果保留并继续加载至 40 条，以及目录详情不变。元数据 fail-once 测试另外核对失败回滚、不发布 revision、相同服务重试和完整 occurrence/order 身份。最终定向运行 37 项测试、七套件通过。

## 集成验证

执行源码 `03b8a1e` 的 [完整 macOS CI 38116679660](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38116679660) 全阶段通过：895 项测试、123 个套件（45.849 秒），8 项发布配置检查，以及 App Intents 元数据、预览打包和上传。 定向测试与完整 CI 是源码证据，不代替各自原生分支。

## 先前受限尝试的解释

后台菜单提交曾触发 state-changed/re-query 守卫，Source popup 的 setValue 返回 -10005；前台阶段曾在首次页面输入前失去目标焦点。这些阶段没有 Save，不能推断应用刷新失败、自动审批拒绝或焦点变更原因。后来原生 runner 的只读副本和字段选择器问题分别纠正：seed 保持 0400，只有自有可丢弃 clone 设为 0600；字段按实际 placeholder 识别。早期失败、实际数据库及清理证据保留在私有 round-3 目录，后续成功不覆盖它们。

## 数字标记的真实保存与刷新

此前字母输入受当前中文输入法转换。额度恢复后，首次数字标记请求遇到真实 macOS 身份认证窗口，自动输入立即停止；提示消失后无法读取其文案，也不推断用途。用户随后明确确认“已完成，可以继续 GUI 验收”，才启动新阶段。

`metadata-xw85-ascii-20261010-a7b6eaa2` 对应私有目录 `xw85-numeric-20261010-a7b6eaa2`，以 `8475d31` 执行源码、0400 不可变 seed 和独立 0600 可写副本运行。测试保留原始标题，仅用原生键盘追加数字后缀；恢复时精确删除后缀。笔记和固定 Library 查询也使用数字，不改变输入法或剪贴板。

实际业务路径已验证：标题 Save 后同一导入歌单详情立即更新且保留第 1/21 页；笔记 Save 后固定 Library 查询同时显示歌曲/笔记；在 Search 恢复原标题后，歌曲匹配消失，笔记所有者更新为原标题；清除自有笔记后，相同查询显示无结果；Back 返回原歌单和原页。协调方独立查看标题、笔记所有者和空状态截图，并直接比较六份只读 SQLite 检查点：目标其他字段、所有其它歌曲/笔记、六张集合真值表和 506 项身份顺序保持不变。编辑目标的 Core Data `Z_OPT` 计数不作为用户数据变更。

私有测试修正与真实影响单独保留。Search 字段使用 placeholder，视频按钮与歌曲行的重复 AX 标签造成结果计数歧义；后者确认为新的 XW-87 应用缺陷。一次测试错误地单击笔记结果，触发了静音隔离实例的播放，未打开编辑器；该阶段实际数据库/队列影响保留，不能声称全阶段没有播放。后续改用真实上下文菜单的 Notes & Bookmarks。另一轮业务完整通过，但退出等待错误地要求已退出应用继续在前台，产生测试收尾失败；业务结果与 XCTest 最终状态分别记录。

最后一次业务测试和所选 suite 的日志为 Passed：1 项、0 失败，53.492 秒，并记录正常 Cmd-Q 后精确目标实际退出。随后外层监督发现一个此前未采样的退场 helper，中断了 xcodebuild；提取的整体 xcresult 为 Failed（1 项业务通过、1 项 runner 取消失败），不能称整次请求全绿。没有为绿灯放行该 helper，也不重复已通过业务。

停止后的真实数据库确认原标题与目标笔记均通过原生操作恢复，其他 654 首歌曲及 506 项集合身份顺序保留；目标 Z_OPT、生命周期表和退出队列存档差异另行审计。旧 seed 的九项 historyRecordID 原本缺失，由既有 QueueService.restore 补齐；其它队列 JSON 语义相同。协调方在随后获准的 XW-87 构建前独立核对十二项保护哈希一致；实际自有进程、runner 容器、产物、data/cache 和偏好物理文件均已清理。完成标记为 xw85-numeric-native-complete.json，协调复核为 coordinator-final-review.json。XW-85 已以此具体修复范围关闭。

该结果覆盖真实导入歌单和保留的 Library Search。非空普通本地 Playlist、远端来源/Pull、真实持久化失败和完整 VoiceOver 仍是更大的阶段验收条件，不因本次通过自动关闭。


## XW-87：Search 视频动作标签被歌曲标签覆盖

原生辅助功能树明确显示，Search 的宽歌曲按钮和右侧 28pt 视频按钮同时获得歌曲名/艺术家标签及同一时长值。视频控件本来定义了“Play in floating video window <title>”说明；`GlobalSearchTrackRow` 在组合 overlay 后再应用歌曲 `.accessibilityLabel` / `.accessibilityValue`，覆盖了独立视频动作的语义。

修复只将歌曲标签和值应用到歌曲 Button，然后组合视频 overlay。视觉布局、命中区域、歌曲播放、队列和视频入口行为均保留。不添加仅比对 modifier 文本顺序的测试；以构建、现有回归和实际渲染的两个按钮标签核验为依据。

`03b8a1e` 已推送，Debug、Release、26 项既有回归和完整 CI 通过。实际 Library 查询 `1000` 读到 1112×68pt 歌曲行“1000日間, noa - Topic”，时长值“—”；独立视频按钮为“Play in floating video window 1000日間”，值为空、28×28pt、enabled 且 hittable。协调方独立核对两者标签和值不再串用，未激活歌曲或视频。私有测试原先把 seed 上传者当作预期显示艺术家，导致断言失败；源码使用 SongCreditCache 的解析署名，这不是标签修复失败。整段测试与清理结果另行记录，不据此宣称完整 VoiceOver 通过。
