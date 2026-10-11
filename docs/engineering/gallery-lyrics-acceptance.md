# Gallery 上方的歌词面板交接

2026-10-11，XW-75 的剩余原生单元发现 XW-88。修复源码为 `3b44632`；只改变 RootView 的禁用和辅助功能隐藏作用范围。

## 原生复现与原因

在 source `03b8a1e` 的可写隔离副本中，从 Home 的真实 Open 动作打开当前歌曲 gallery，再通过公开 AppIntentsTesting 调用一次 SearchLyricsIntent。框架返回且 query 正确，但标题输入框和 Close 连续两次读到 enabled=false、hittable=true。图库仍保留。测试停止业务输入，没有强点禁用控件或反复发送键盘。

RootView 原先在包含 sheetHost 的 notificationWired 外施加 gallery 的 disabled/accessibilityHidden。LyricsMatchPicker 的标题和 Close 自身没有加载期间的禁用逻辑；面板继承了背景禁用环境。现在两项修饰符仅应用于 continuityChrome(splitView)，位于原生 alert/sheet 呈现之前。图库背景继续隔离；gallery 状态、请求路由、播放和队列语义保持。

## 验证

Debug 7.74 秒、Release 64.47 秒通过；GalleryPreviewPresentation、BrowseNavigationHistory 与 AppIntentHandoff 三个既有套件共 12 项测试通过（0.010 秒）。重新生成的 App Intents 元数据在规范化 resolvableInputTypes 顺序后字段一致，本地化资源一致，四项正常应用及已安装应用核心文件哈希保留。没有添加仅比对修饰符文本顺序的测试。

执行源码相同的 `f635d62` [完整 macOS CI 38122069515](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38122069515) 通过 895 项测试、123 个套件（44.479 秒）、8 项发布配置检查、App Intents 元数据、预览打包与上传。

修复后的独立原生 gallery 单元通过：一次真实 framework 请求的 query 正确，输入与 Close 两次读到 enabled/hittable；Close 后保留原歌曲的标题、署名和封面，Done 后恢复暂停、音量 0 的 PlayerBar。协调方独立查看四张精确窗口截图，并核对两次背景 PlayerBar artwork 的 AX 计数为 0。精确标题 staticText 选择器仍为 false，身份由实际 AX text-value 数组和前后图证核对，不以选择器缺失推断内容缺失。

完整 XCTest 为 Passed，1 项通过、0 失败，请求 exit 0、15.09 秒；原生 Command-Q 后精确 PID 在 teardown 前退出。停机后先保留 SQLite backup 检查点，再清理。协调方直接核对 27 表完整性、21 表（仅排除各自 ORM 版本）以及 session/queue 语义：655 首 Track 和 60 条播放事件保留，九项历史条目由既有恢复路径补齐 historyRecordID，其余解码队列内容一致；会话/保存时戳和 ORM 记账单独保留。八项保护哈希、0400 seed、零自有进程和精确资源清理通过。XW-88 已关闭。

## 相邻单元与证据边界

修复前的 import 对照在空链接 overlay 上直接呈现歌词 sheet，query 正确，输入与 Close 可用；Close 后原 overlay 仍存在，Cancel 正常，保持暂停和音量 0。它接受空链接状态的交接，不扩大为完整导入矩阵。该业务单元通过，但 runner 内合作退出请求返回 false，完整 XCTest 为 Failed；gallery 的退出键同样没有证实退出。两实例均在框架失败收尾期间消失，不能称正常或合作退出通过。

协调方独立复核此阶段八项保护哈希、0400 seed、零自有进程和精确产品/资料/偏好/容器清理。最终 gallery 副本的完整性和 27 表/60 个播放事件审计保留；import 副本在 gallery 准备前已重置，没有单独的逐表检查点，不补造该证据。未激活媒体或选择/保存歌词。

旧窗口复合路径的 XCTest Command-[ 超时仍未归因；此前独立 Cua 键盘、View Back 和可见歌词面板对照继续保留自己的范围。本次修复不证明自动 Intent 冷启、视频模态、手动 Siri、macOS 26 或完整 VoiceOver。

私有原始证据：round-3/intent-overlay-route-20261011-21034d2e。修复产物与测试：round-3/xw88-source。修复后的原生证据与停机检查点：round-3/xw88-gallery-native-20261011-bdf46095。
