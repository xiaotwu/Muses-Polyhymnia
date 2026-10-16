# EQ 与外部歌词关闭后的返回位置

2026-10-15，本机两个独立原版本进程均出现：EQ 位于顶层时，一次外部歌词请求正确呈现；关闭歌词后返回 Audio Info，而非原 EQ。用户随后明确选择“关闭歌词后回到原 EQ”，跟踪为 [XW-102](https://linear.app/xiaotwu/issue/XW-102)。窄修复已通过下述本机回归、原 EQ 返回及活跃 Save As 等待小节；修复前对照与未接受的草稿重开结果继续保留。[PR #10](https://github.com/xiaotwu/Muses-Polyhymnia/pull/10) 已合并为 `9a85c48`，精确 PR head 的 [CI 38831450672](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38831450672) 与精确 merge 的 [main CI 38832872757](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38832872757) 均通过全部 11 阶段，XW-102 Done。后续删除确认 Cancel 小节在本文末尾单独记录；正式 0.6.0 未更新，父项 XW-75 继续 In Review。

## 原版本与执行边界

两次对照均使用合并源码 `1094dbfa55a001eac0e5896aad2120a8dbe3fe7f`、空补丁与冻结的 444 项输入，签名隔离候选为 `com.muses.acceptance.audio-info-eq-oct15` / build `20261015.7502`。这份源码包含已完成的 [XW-101 模糊／精确搜索](lyrics-search-modes.md)，不是 XW-102 修复版。正式 0.6.0 未替换或启动。

候选整份复制 [Audio Info 小节](audio-info-intent-acceptance.md) 通过真实界面建立的新暂停种子：一首 **Avant-garde HISTORY** / **Roselia - Topic**，video ID `YfY82CJjyII`、播放计数 1、零 listening events。原始 SQLite 为 0400，闭合备份为 0600；没有恢复已由用户清除的旧库，也没有注入记录。

每个新请求使用独立目录、排他消费标记和精确路径／bundle／build／PID／launch identity 门槛。公开 AppIntentsTesting 的 UI-testing runner 不指定产品或正式应用为测试目标，源码没有 UI 自动化、启动、激活或终止操作，也没有重试。q2 使用独立复制并重新限定写权限的 runner；q1 原产品、请求和完整结果保持。每份源码一次 `run()`、一次 XCTest run，不证明框架内部只传输或投递一次；两个请求均不得重放。

## 两次真实关闭对照

两次均从同一录音暂停 0:09、音量 0% 开始，经 Playback → Audio Info → Open EQ。EQ 为 Flat，十段 0 / +0.0 dB、bypass Off，频率 1k／增益 0.0 自动选中；没有修改增益、预设、bypass 或输出设备。

| 单元 | 进程与请求 | 实际歌词及关闭动作 | 返回与退出 |
| --- | --- | --- | --- |
| q1 | PID 63065；`audio-info-eq-lyrics-01` | 正确 query `Avant-garde HISTORY`、艺人空、全部来源、默认模糊；8 个未选候选，使用按钮禁用。Tab 到 Artist 后 Escape。 | 返回 Audio Info，未见原 EQ；未使用 EQ 自身 Close。Audio Info 自身 Close 后仍同曲暂停／静音，正常 Command-Q。 |
| q2 | 新 PID 65617；`audio-info-eq-lyrics-02` | 相同 query／来源／模式及空艺人；6 个未选候选，使用按钮禁用。Tab 到 Artist 后点击可见歌词自身 Close，未输入 Escape。 | 同样返回 Audio Info，未见原 EQ；未使用 EQ 自身 Close。Audio Info 自身 Close 后仍同曲暂停／静音，正常 Command-Q。 |

q1 首次 Open EQ 输入被界面工具的状态守卫中断；精确 PID／摘要校验及新 AX／截图回读后，后一次点击打开 EQ。该守卫不等于崩溃，也没有把它归因给用户。q2 没有该中断。

q1 的 Audio Info 设备标签从 TCL TV 变为 MacBook Pro Speakers。用户确认期间切换或连接状态变过，随后说明误切换过、现已调整为 MacBook 模式。q2 前后均显示 MacBook Pro Speakers。没有独立系统事件追踪，不能据此证明应用自发修改默认输出。q2 延续 q1 停止资料／偏好，外部设备环境和候选数也有差异，因此不是全环境严格单变量 A/B。

可见 Close 也出现相同返回位置，说明 Escape 不是这次观察的必要条件。原 EQ 在歌词呈现时还是关闭时失去可见返回位置仍未定位；顶层 AX 树缺席本身不证明 EQ 已销毁或确定销毁原因。界面观察来自协调方的 AX／截图记录；独立审计核对封存框架和资料，未另行重做图像观察。未选择或应用歌词，不接受来源候选的录音身份、歌词匹配或 EQ 听感效果。

## 完整框架结果

两份完整 xcresult 均为 Passed 1 / 0、exit 0、一次测试运行、三项内部活动（Start Test／Set Up／Tear Down），没有媒体附件或性能指标。精确目标 PID 和同一 launch 在调用前后保持。

| 计时层 | q1 | q2 |
| --- | --- | --- |
| XCTest 用例 | 0.615957 秒 | 0.329929 秒 |
| 源码一次 `run()` 等待 | 0.218579 秒 | 0.128313 秒 |
| xcresult 时间窗 | 4.862 秒 | 1.364 秒 |
| 外层命令 | 5.844136 秒 | 1.950598 秒 |

这些是执行层计时，不是性能基准。两份结果的 `runtimeWarnings` 为空，但外层日志仍有 CoreSimulator 版本不符和多个匹配 macOS destination 的警告；不能写成整段无警告。框架 Passed 不代表原 EQ 返回条件通过。

## 修复前原版的闭合资料与保护

q1 的 startup、输入守卫后、投递前、投递后、歌词关闭后和最终暂停六份数据库字节完全相同；q2 的 startup、投递前／后、歌词关闭后和最终暂停五份也各自字节完全相同。独立审计比较全部 27 表的类型／值／重复行及 64 项结构。每轮最终暂停到正常退出均只有五个生命周期／checkpoint／ORM 表变化，22 表全值相同；相对原始种子，两轮停止结果均有六表变化、21 表全值相同，不能统称全库不变。

完整 Track 始终同值，歌词为 NULL、播放计数 1；没有新增事件或 EQPreset。七项 Queue JSON 和两项 Session JSON 解码均等于原始种子，单项队列、occurrence／顺序／来源上下文、空历史／Up Next、repeat Off 和 shuffle 关闭保留。q1 正常退出将两处保存位置从 8,693.356009070294 ms 写为 8,693.333333333334 ms，差 −0.02267573696008185 ms；q2 全程保持后者，相对 q1 停止没有新增位置差。持久化 session 的 `active` 不是正在播放的证明，暂停状态来自原生观察。

两轮停止偏好均为 21 项，初始 18 项逐类型／值保留，新增窗口位置、十段 EQ 数据和输出设备偏好。q1 与 q2 之间仅 EQ JSON 数据字节不同，解码的十段 gain 0／q 1 相同。两轮保存的设备偏好文本仍为 TCL TV；它与末次界面设备标签分开记录，不充当系统实际输出选择或原因证据。

独立复核确认原始 0400 种子、旧 a1/a2 请求与 q1 材料保留，候选关键摘要／资源／元数据／严格签名匹配；正式干净安装的完整 207 项清单相同，正常资料目录及正式物理偏好文件仍缺席，Keyboard Navigation 为 0。源码哈希核对发生在各轮停止之后，与 runtime 停止时间分别记录，不能称为运行当时的连续监测。

私有证据位于 `~/.muses/tmp/engineering-oct15/audio-info-eq-intent/`。依据为两请求的 `native-result.json`、完整日志／xcresult，以及 `independent-review/q1-public-intent-result-review.json`、`q1-closed-protection-review.json`、`q2-public-intent-result-review.json` 和 `q2-closed-data-protection-review.json`。原候选曾保留用于修复对照；完成对照后的归档及精确清理见本文末节，原始请求与审计保留。

## 用户合同与源码修复

新合同是：从已打开的 EQ 接到外部歌词请求后，歌词关闭应返回原 EQ，并保留其编辑状态；其后才由 EQ 自身关闭返回 Audio Info。修复前两轮按这个已明确的合同均不接受为通过，不回写成早先已经证明的产品根因。

修复让 Root 持有一份请求及 EQ 呈现 binding；EQ 活跃时由现有 EQ 承载歌词子 sheet，Root 不同时呈现同一请求。Audio Info 传递该 binding，EQ 原有 bands、selectedFrequency 和 newPresetName 仍为原视图的状态，不通过 dismiss／重建或请求 ID 强制换视图。共享的请求／host 判断和失效请求 binding 保护隔离非活跃或过期呈现；EQ 的 Save As／删除确认活跃时暂存请求，结束后再呈现。

独立静态审阅覆盖四个生产文件和新回归文件，没有发现必须先修的确定问题。旧 host、旧 request ID 和先前空 render 的 nil 回写不能清掉当前请求；局部对话框阻塞时，Root 不抢占，canonical request 保留。普通 Audio Info、未保存歌曲信息草稿、Quick Search、视频和冷启动继续走 Root；Intent／Shortcuts 定义及单实例入口没有改动。逻辑 fixture 不证明真实 sheet 的身份或动画时序，原生结果另列。

## 本机构建与资格

执行输入为 `1094dbf` 加源码补丁 `b14e7e72…`，共 446 项冻结输入。新增 12 个 `@Test`，参数展开后共 14 个具体案例；定向报告 12 项／1 套件通过（0.003 秒）。完整 Swift Testing 为 998 项／134 套件（32.377 秒，保留 9 项 opt-in 跳过边界）。14 项发布配置检查（1.195 秒）、独立真实磁盘失败／重试 1 项／1 套件（0.041 秒）通过。Release 产品、helper 构建入口及 Xcode 构建均成功；不据 helper 入口成功声称每个既有 helper 文件重新编译。

候选为 `com.muses.acceptance.eq-lyrics-return-oct15` / build `20261015.10201`，新 UUID `753C7CBC-30DF-3BAF-90F3-8FCE8A80D0C6`，实际 minOS／SDK 均为 26.0。可执行文件来自本轮 Swift Release 输出 `.build/out/Products/Release`，不是稍后 Xcode 的 `.build/out/Build/Products/Release`。元数据由本轮处理器输出，但两处 constvalues 复用了字节不变的既有合格输入，不能称为本轮新编译器产出；Intent、Shortcuts、入口与相关冻结输入保持，精度说明和独立补充收据保留。17 项资源中 16 项与新 Release 资源直接同字节，另一项为有意覆盖的官方已签名 yt-dlp，两处工具路径均核对。完整资源、签名、元数据及新身份通过独立资格检查。

新候选重新从原始 0400 真实种子整份复制为 0600，初始为新设的 18 项静音隔离偏好，没有继承原版 q1/q2 的 21 项停止偏好。两套独立 runner 的生成 sandbox 权限逐值保留，分别只新增各自 request01／02 目录的写权限；嵌入测试字节相同，UI-testing／runner-hosted 标志、公共框架链接、同团队严格签名、无指定产品应用及零 UI 自动化／目标启动核对通过。

## 修复后实际 r1 小节

两份新请求 `eq-lyrics-return-01` 和 `eq-lyrics-return-02` 在同一新 PID 73777、同一 launch 中各运行一次。完整 xcresult 各 28 个文件、Passed 1 / 0、exit 0、一次测试运行及三项内部活动，无媒体或性能附件。两套源码各只调用一次 `run()`，标记均已消费；没有重放旧请求，也不推断系统内部投递次数。

| 计时层 | request01 | request02 |
| --- | --- | --- |
| XCTest 用例 | 0.423594 秒 | 0.323744 秒 |
| 源码一次 `run()` 等待 | 0.185452 秒 | 0.102188 秒 |
| xcresult 时间窗 | 1.897 秒 | 1.487 秒 |
| 外层命令 | 2.478832 秒 | 2.052475 秒 |

日志仍含上述 CoreSimulator／多目标警告，计时不是性能基准。独立审计核完整结果、proof／events／排他 marker 和精确身份；下列界面结果来自协调方的实际 AX／截图操作及封存的 retrospective `native-result.json`，不是独立审计重新做过 GUI。

1. 从 Audio Info 打开原 EQ，只把频段选为 4k，保持十段 gain 0、Flat 和 bypass Off，没有播放、改增益／预设／输出。request01 正确显示 `Avant-garde HISTORY`、空艺人、全部来源和默认模糊，8 个候选未选、使用按钮禁用。Tab 到 Artist，点击歌词自身 Close 后返回原 EQ，4k 和平直状态仍在。
2. 重开 Save As 时 Name 在画面／AX 中为空，不能接受为草稿恢复。随后使用正常粘贴、Cancel、重新打开，期间没有新 Intent，Name 仍为空。该对照说明这个观察不依赖新增歌词请求，不定位原因；不声称 Cancel 后重开的草稿保留。
3. 保持同一 EQ，在活跃 Save As 中粘贴唯一诊断草稿，提交新 request02。框架返回后仍显示原 alert 和精确草稿，歌词没有覆盖它。点击 Cancel 后，无需重发即自动出现正确 query 的歌词窗口；空艺人／全部来源／默认模糊保持，终态为无匹配，没有选择或应用。Tab 到 Artist、Escape 后返回原 EQ，4k、十段平直及 bypass Off 保留。
4. EQ 自身 Close 返回 Audio Info，Audio Info 自身 Close 返回同曲暂停 0:09／音量 0%；前后设备标签均为 MacBook Pro Speakers。正常 Command-Q 后精确候选／runner／helper 进程缺席，并返回源码阶段；没有改变系统键盘导航，模式为 0。

本 r1 轮接受的是可见 Close 与 Escape 返回原 EQ／4k 状态，以及**活跃 Save As 跨请求**的文本保留和延后呈现。r1 没有 Save／删除预设，未接受删除确认的原生路径、Cancel 后草稿恢复、EQ 听感效果或歌词来源身份；也没有新增草稿、Quick Search、视频、冷启动的原生覆盖。后续独立删除确认 Cancel 小节不回写为 r1 的结果。独立框架收据为 `eq-lyrics-return-repair/independent-review/r1-public-intent-results-review.json`。

## 修复后闭合资料与收尾边界

独立 `r1-closed-data-protection-review.json` 已比较十份实际闭合备份及原始种子：64 项结构相同，startup 至最终暂停的九份业务检查点全部 27 表逐类型／值相同。正常退出只改变五个生命周期／checkpoint／ORM 表，22 表保持；相对原始种子仍为六表变化、21 表保持，不声称整库字节不变。Track 全部 35 字段同值，歌词为 NULL、播放计数 1，事件和 EQPreset 均为零。七项 Queue／两项 Session JSON 解码等于种子，身份、occurrence、顺序及上下文保留。业务期两处位置均为 8,693.356009070294 ms，Quit 后均为 8,693.333333333334 ms，差 −0.02267573696008185 ms。

本轮停止偏好实际为 **20 项**：初始 18 项逐类型／值保留，仅新增窗口位置和 EQ JSON 数据；十段 gain 0／q 1，逻辑、物理与停止快照同值，没有输出设备偏好键。不能套用原版 q1/q2 的 21 项结果，也不从此键缺席推断系统输出。446 项源码、候选／runner 产物和原版对照的受保护 4,255 个条目、原 0400 种子及当前 Release 关键文件核对保持；正式安装完整 207 项清单相同，正常资料／正式物理偏好仍缺席，模式为 0。实际核对时间与 runtime 退出时间分开记录。

原版及修复候选的自有 app、namespace 和四套 runner 构建目录，已先归档为 291,286,049 字节、7,574 条目的主包（5,166 文件／2,388 目录／20 字面链接）。协调方和独立审阅者直接对仍存在的原件核对类型、模式、文件字节及链接目标，执行前再检查，随后删除八个精确目录并清空两个自有逻辑偏好域；物理空 plist 保留。两个由 metadata ID 确认归属的 runner 系统容器另有 96 条目补充归档，经协调方直接原件核验后精确移除。六个候选／runner 路径已执行精确注销；中间 dump 仍有两条 host 记录，随后仅对这两处已删除的自有路径再次注销，`registration-followup.json` 记录 fresh dump 为空。独立后验再读 dump，确认六个自有 identifier 无记录；不把最早注销当作持续全空证据。

归档与清理收据分别在 `archives/eq-lyrics-return-completed-20261015/` 和 `archives/eq-lyrics-runner-system-completed-20261015/`，独立 `completed-cleanup-postcondition-review.json` 已通过。两归档均为 0400，后验核对主包与保留清单、系统容器元数据和精确路径缺席；不声称删除后重新读取过原件。源码、原始 0400 种子、23 份闭合备份、原版／修复四份请求的完整原始结果／xcresult、17 份顶层日志及协调方收据仍在原位；runner build 内部 Logs 已随构建目录完整归档，不能统称所有日志仍在原路径。正式版 207 项、正常资料／正式偏好缺席、当前产品构建、模式 0 及相关进程缺席再次核对。集成状态见本修复 PR／[XW-102](https://linear.app/xiaotwu/issue/XW-102) 实时记录；手动 Siri／Shortcuts、实际 macOS 26、完整 VoiceOver／设备矩阵及性能范围仍归 XW-75，父项继续 In Review。

## 远端验证与删除确认 Cancel 接续

PR #10 的完整 CI 实际为 998 项／134 套件（56.159 秒、9 项 opt-in 跳过）、发布检查 14 项（5.003 秒）和独立真实磁盘失败恢复 1 项（0.108 秒）。合并 main 为 998 项／134 套件（64.379 秒、相同跳过边界）、发布检查 14 项（10.035 秒）、独立磁盘恢复 1 项（0.184 秒）；两者元数据、ad-hoc 预览打包、签名验证及上传均通过，全部 11 阶段成功。预览不等于 Developer ID 正式签名、公证、appcast 或正式发布。main 的 whole tree 与已验 PR head 相同。两份完整 job 日志及 run ZIP 已保存并逐成员核对；早期收据误写 ZIP 成员数 14，保留原件并以 v2 更正为实际 13，不涉及 CI 重跑或测试结论变化。

后续 `com.muses.acceptance.eq-delete-followup-oct15` / build `20261015.10202` 复用已验本机 Release／helper 字节、资源和元数据输入，没有重新构建产品。446 项产品输入与合并源码相符，静态资格另行核验。新 namespace 再整份复制原始 0400 真实种子并设为 0600，初始 18 项隔离偏好。f1 通过真实 EQ Save As 建立唯一预设 `XW75 Cancel 10202`，十段 gain 0／q 1、bypass Off；没有改变增益。此预设只属于隔离副本，后续不重置或注入资料。

f1 在打开该预设的删除确认后启动 UI runner，但测试工具启用自动化模式超时，exit 65；源码测试及 `.run()` 均未执行，events／proof／消费标记缺席。legacy metrics 为 testsCount 0／errorCount 1，modern summary 的 total 1／failed 1 是初始化的 synthetic System Failure，不能写成产品交接失败或通过。协调方取消确认并正常退出，完整失败日志／xcresult 与六份闭合备份保留。

f2 沿用 f1 停止后的真实预设及资料，以新 PID 84034、新 request02 和独立构建的 gated UI runner 继续；旧 request01 不重放。新 runner 先在普通 EQ 状态完成初始化，写出绑定 PID／launch／nonce／host 的 `harness-ready.json`，在最长 120 秒的异步等待内，由协调方使用 Cua 打开删除确认并保存检查点，再显式发布完整审批文件。源码重新核对身份后消费排他标记，调用一次 `.run()`；没有目标启动、UI 自动化、重试或产品测试目标关联。

真实框架返回后，原“删除预设？从本机删除「XW75 Cancel 10202」。”确认仍在，歌词没有覆盖它。点击实际 Cancel 后，无需重发即出现 `Avant-garde HISTORY` 查询、空艺人、全部来源及默认模糊搜索；8 个候选未选，使用按钮禁用。Tab 到 Artist 后点击歌词自身 Close，返回同一 EQ，原测试预设仍被选中，1k／0.0 dB、十段平直和 bypass Off 保留。随后 EQ 自身 Close → Audio Info 自身 Close，设备前后均为 MacBook Pro Speakers，主窗口同曲暂停 0:09／音量 0%，正常 Command-Q 退出。

完整新 xcresult 为 Passed 1／0、exit 0，proof 记录一次源调用及同 PID／launch；外层 121.230 秒包含初始化与协调方的 UI 审批等待，不能当作请求延迟或性能基准。界面操作全部由协调方 Cua 完成，没有真人复验；AX／截图在工具对话中，retrospective `native-result.json` 与计时措辞澄清附录单独保存，不声称独立审计重做了 GUI。

f2 的七份业务检查点字节相同；正常退出另记生命周期保存变化。完整 Track 保留，歌词 NULL、播放计数 1、事件 0，唯一真实测试预设全行及其十段参数保持，Queue／Session JSON 语义保留。停止偏好仍为 21 项：初始 18 项全值保留，新增窗口位置、当前 EQ 数据和活动预设 ID；f1 → f2 的 20 项逐类型／值相同，EQ Data 仅 JSON 对象键顺序不同，解码十段参数相同，不能称全部原始偏好字节不变。正式版完整 207 项、原始 0400 种子、当前产品构建及历史封存材料保持，正常资料和正式物理偏好仍缺席，系统键盘导航为 0。

此接续只接受删除确认阻塞、Cancel 后保留请求并自动呈现，以及歌词自身 Close 回原 EQ。没有实际确认 Delete、播放、应用歌词、修改输出／系统设置或新增 EQ 听感结论。私有完整材料在 `eq-delete-confirmation-followup/`，闭合审计和精确资源收尾以其独立收据及 XW-75 记录为准；完整系统、账号、VoiceOver、实际 macOS 26 与其他未测呈现条件继续保持未接受。
