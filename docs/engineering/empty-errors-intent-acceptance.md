# 无当前录音与无效链接的 App Intent 验收

2026-10-16，XW-75 新接受四项限定检查：无当前录音时的歌词提示、其自身 Close 与 Escape 关闭，以及不支持网址的公开拒绝和不存在本地录音的原生错误提示。四项均无需产品源码修复；XW-75 继续 In Review。

## 环境和执行边界

本机实际为 macOS 27.0.1（26A434）、arm64。候选 `com.muses.acceptance.empty-errors-oct16`、build `20261016.7504`，同一新启动单元 `e1`／PID 4918，产品源码为 `8edbe1ae2da4a8a2c8f217b2291fe08b0007b734`，446 个输入与已接受版本相同。沿用既有 Release 产物／17 项资源和两个编译 constvalues，重新处理 App Intents 元数据，再以原 Team 签名独立候选；没有重新编译产品或替换正式版。

候选完整 207 节点、四套独立 runner Products 各 26 节点及签名／元数据／路径经过独立实际核验后冻结。候选 namespace 在启动前确实缺席，由真实首次启动建立，没有复制暂停种子或注入 SQL。首页显示“未在播放”，Play、Lyrics 和传输按钮禁用，音量 0%，数据库 Track 为 0；这组原生读回与闭合备份共同限定无当前录音条件，不能由暂停或空列表替代。

每项使用独立 public AppIntentsTesting UI-test helper。helper 不指定产品测试目标，也不启动、激活或自动操作产品 UI，只在原 generated sandbox 上增添本项精确请求目录写入范围。实际 ready 后，协调方重新读回候选界面，保存本项新的 0 Track 检查点，再显式批准绑定 nonce、PID／launchDate、hostPID、ready 和备份摘要的单次触发。每源仅一处 run，四项均只消费一次；这不证明系统内部仅传递一次。

## 四项结果

| 请求 | 公开框架边界 | 原生观察与操作 | 接受范围 |
| --- | --- | --- | --- |
| `no-track-close-01`／`XW75 NoTrack Close Oct16` | SearchLyricsIntent 普通返回，同一目标身份 | 新 sheet 显示“请先播放歌曲／歌词会匹配当前录音版本。”；点击自身“关闭”回首页 | 无录音提示及自身 Close |
| `no-track-escape-01`／`XW75 NoTrack Escape Oct16` | 第二份 SearchLyricsIntent 普通返回，同一目标身份 | 独立新 sheet 显示相同提示；单次 Escape 后回首页 | 此新提示的 Escape |
| `unsupported-link-01`／`https://example.com/xw75-unsupported-oct16` | PlayYouTubeLinkIntent 实际抛错，完整公开 localizedDescription 为“这不是受支持的 YouTube 视频链接。” | AX／画面仍为未播放首页，没有 Root 错误弹窗 | 参数拒绝的公开可观察消息 |
| `missing-track-01`／`muses://play?trackId=6068d2bc-7c5b-4dcc-a5de-f0697a08f87c` | PlayYouTubeLinkIntent 普通返回，同一目标身份 | 实际 alert“无法打开链接／无法打开此视频，请检查链接后重试。”；点击自身“好”关闭回首页 | 不存在本地录音的异步解析错误／自身 OK |

两次无录音提示不呈现查询输入框；固定 query 的框架绑定记录与原生提示分别保留，不声称在界面读到了该 query。缺失录音项使用新合法 UUID，触发前 0 Track 证明其不存在；源码该分支直接查本地录音，未进入视频 importer。普通公开返回不表示异步播放成功，必须另核实际 alert。

不支持网址项保留整个公开 NSError／标准 underlying 与 multiple-underlying 图、类型／domain／code、完整消息、传输排除结果和事后目标身份。实际为一个 root 节点，完整、无环且未截断，精确全文匹配上述中文消息，未发现已知取消／网络／启动／XPC 等传输信号；记录 `runThrew=true`、`runReturned=false`、`expected-rejection-message-observed`、`internalErrorTypeUnproven=true`。这接受公开错误消息，不从 debug/domain 文本推断私有枚举身份或精确内部 perform 路径，也不保证识别所有未来传输错误。泛化错误、超时、普通返回或不完整错误图不会被计作此项通过。

四份完整 xcresult 均 Passed 1、failed 0、skipped 0，外层 exit0。按上表顺序，单测试时长为 14.463／18.363／17.134／18.827 秒，外层执行为 22.514／19.804／18.545／20.195 秒；包含人为门控等待，不是性能测量。完整日志保留 CoreSimulator 版本不匹配诊断和多匹配 destination 警告；实际选中本机 arm64 macOS。结果摘要没有 runtimeWarnings，不将整段日志写成无警告。原生 AX／截图和 Close／Escape／OK 是协调方本轮观察，独立复核只审核封存材料，没有重放界面。

## 资料、偏好与保护

十四份闭合备份（启动、每项触发前／提示／关闭、最终首页和正常退出）均 quick_check=ok，27 表 schema 与完整 typed values 一致，而且全部文件字节相同。Track、Queue、Session、ListeningEvent、Notes、Bookmarks、EQPreset、imports 及 ORM history 均为 0；无队列／会话位置，不能沿用前轮的位置或退出舍入结论。原始 WAL／SHM 如存在随 namespace 归档；检查点仅通过只读源备份到独立目标，复核使用 immutable／query_only 并关闭连接。

实际偏好为 18→20 项，原 18 项完整类型和值一致，仅新增窗口 frame 与十段平直 EQ Data（gain0、q1），没有 browseRoute。各次原生读回 volume0，没有播放有效媒体，未点击 Play、Import、Save 或 Apply，也未变更系统键盘导航、账号或输出设备。正常 Cmd-Q 后被动确认自有进程为 0，停止备份与真实偏好导出另行保留。

正式 `/Applications/Muses.app` 0.6.0 完整 207 节点、当前 Release／资源／constvalues、原始 0400 单曲暂停种子和既有证据保护独立核对。正常 data 与正式物理偏好域仍缺席，未把用户已清除的历史资料写成恢复。旧证据由本层新增 4 树加继承保护 7 树组成，共 11 份完整树，原先 174 项保护继续有效。

## 归档与整合

主保留包 `owned-empty-errors.tar.gz` 为 281,482,756 字节、14,440 成员，SHA256 `8fb982c2130a06fe02c06d20e95b8e56faaf15d44b3b81fecce245bb547b5425`；独立直接核对每个原件／tar 成员的类型、模式、大小、摘要和链接目标及真实 20 项偏好后，才清理候选、namespace 与四套完整构建共六个精确目录。共享 runner 容器另以 metadata 精确身份核对 48 成员归档，SHA256 `8eaa0db2dde0248e4b40cc7b762896b294910f0e0619ecfbd92b1d15d8528ec4`，并在主清理成功后单独移除；五个精确注册路径各注销一次，实际三种标识均无残留。自有逻辑偏好清空，物理空 plist 留存。全部源稿、实际请求／完整 xcresult、闭合备份和 sidecars、原种子及既有证据保留。

私有材料位于 `intent-empty-errors-oct16`：`root-native-result.json`（`6224dacbe5d7…`）记录本轮界面归因；`independent-review/e1-closed-data-protection-review.json`（`8fd3f85ca5bd…`）关联完整四请求链和 typed 资料／偏好复核；主预删除独立收据为 `af2c7d5e762b…`，系统原件／tar 直接复核为 `39cd7b6e1202…`。归档和清理输出均在该 scope 的 `cleanup-preparation`，包含未采用稿、源审阅、更正、两套清理结果及完整前后 LS 原始 dump，不改变原有十一树。

本轮准备期间的命令签名参数遗漏、旧 freeze schema 和证据层数错误均在执行前发现，未采用原稿保持封存；不声称它们造成了实际 build／archive 失败。最终四套 helper 均一次构建成功。产品源码、测试和构建配置不变；本轮文档整合的精确 CI 和父引用待整合后由 GitHub／Linear 实时记录精确回读；先前提交的成功不替代新提交检查。

## 剩余条件

只增加上述四项本机条件。手动 Siri／Shortcuts 的唯一来源绑定及实际执行、真实 macOS 26、完整 VoiceOver／设备／焦点矩阵和其他未测呈现／错误条件继续保留。未测试有效媒体链接播放、真实提供方不可用、账号切换或全部 URL 变体；先前 Edit Info、Audio Info、EQ、Import、Notes 结论和失败证据保持原范围。未发布新正式版，也未发布家族 Pages。
