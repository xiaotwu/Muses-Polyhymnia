# 发布后输入与歌曲署名检查

2026-10-13，先确认旧 main CI 全绿，完成 XW-93 受控分页修复并集成；本页记录随后两个正式版检查小节和用户新报告。正式版仍为 `/Applications/Muses.app` 0.6.0 / 20261012.1，macOS 27.0.1 / arm64，1280×804pt、Light、封面模式。没有替换应用、远端写入、修改系统设置或下载语言包。

## Queue 上方的歌词 Intent

使用独立无 app host 的 AppIntentsTesting runner，精确绑定正式路径/签名摘要；只有一个唯一请求、一次 `run()`。数字 query 是显式验收参数，不是自动从歌曲身份生成的默认查询。实际歌词 sheet 正确收到参数，歌名字段 5 获焦点，Tab 进入艺人字段 6；Escape 只关闭 sheet，原 Queue 及当前集合 530 项仍在。随后只关闭本轮打开的 Queue。

完整 XCTest Passed 1/0，方法 0.270 秒；独立审阅唯一调用、五份 AX/截图及完整 result 后接受这个有限小节。27 表/schema、13 张保护表（含 Track，忽略 ORM 版本）、七个 queue JSON、会话位置/队列/当前曲及 45 项完整偏好一致；673 首歌曲、78 条事件，没有计数变化。正常资料库未覆盖或恢复旧备份。

runner 产品、注册和容器已清理；完整 result 归档及 SHA、前后实际在线只读备份保留在 `~/.muses/tmp/engineering-oct13/xw75-queue-runner/`。这只补齐 XW-75 的 Queue 呈现和 sheet 输入，不等于手动 Siri、物理键盘、VoiceOver、macOS 26 或歌词提供方成功。

## PlayerBar 封面逐页检查

用户报告特定页面进入播放界面时侧栏不隐藏、重叠封面，无法记起具体页面，要求全面测试并确认入口为点击 PlayerBar 封面。本轮在以下十二个浏览目的地分别投递指针点击，再检查实际画面、退出和保留的暂停上下文：Home、Search、New、Songs、Albums、Artists、Liked、Music Videos、Podcasts、Subscriptions、History、Playlists。另补导入 Liked 详情。先期 Home/Search/New 的 AX 入口对照另存，不重复算作十三个指针单元。

这十三个有限条件的稳定画面均未复现侧栏持续显示；真实歌词分栏也未显示侧栏。AX 在 opacity 为零时仍可列出导航控件，不能拿 AX 存在作为可见性证据。Focus Navigation 尝试未取得 activation-control 焦点，定点滚轮也未建立真实 hover，因此这两项不接受为焦点/hover 验收。尚未覆盖紧凑尺寸、其它外观、物理 hover 和 300ms 退出过渡内的快速重开，不能据此关闭用户的间歇报告。

源码确认所有 PlayerBar 封面入口共用 `openNowPlaying`，没有某页保留侧栏的分支。独立审阅指出 hover/focus 重置依赖侧栏 `onAppear`，快速关闭/重开时的复用是后续假设，尚未证明根因。XW-96 Backlog 保留报告、阴性范围和这些具体排查条件。

## 普通歌词查询与署名

从普通歌词菜单打开「匹配歌词」，默认歌名为当前真实视频标题，艺人字段为视频发布者；这次没有数字 ID 默认值。它只说明当前录音的入口结果，不否定用户其它录音的报告。打开歌词时系统提示下载翻译语言，已用 Escape 取消，没有下载；原文保留，翻译显示暂不可用，没有 Apply。

XW-94 追查删除/换账号/重导入后的旧署名：现有相同 video ID 的 Track 被复用，旧 artist 保留；显示层只知道当前导入的 owner，旧 owner 可能被误认作手工或真实艺人。修复必须依据精确视频来源事实，区分真实 artist、视频发布者与歌单 owner，保留 UUID、喜欢、历史、队列和手工 metadata，先做冷上下文受控复现。永久删除后失去来源证据、以及 tombstone 重导入语义仍须分别核对。

XW-95 追查默认歌词输入：初始化不会等待或跟随后到的 verified metadata，自动/桌面查词仍可能拿原始 publisher/旧标题。先验证迟到 metadata、明确 placeholder/标题恰为视频身份、仅 owner/publisher 的艺人，再准备真实默认输入；显式 Intent query、用户编辑和真实数字歌名必须保留。不能把本轮验收数字值当作已证实的普通入口缺陷。

逐页检查结束后，13 张保护表和所有表计数、完整偏好仍一致。正式版恢复导入 Liked122/530、暂停26.6666秒、50%音量、单曲循环/关闭随机；歌词、Queue 和视频关闭。证据在 `~/.muses/tmp/engineering-oct13/formal-sidebar-oct13/`。剩余具体修复与验收继续由 [当前状态](current-status.md) 和 Linear 管理。
