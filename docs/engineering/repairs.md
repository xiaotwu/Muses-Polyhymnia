# 缺陷与修复分析

本页只把可复现行为或实际编译失败列为缺陷；未验收分支与测量候选分别见 [功能验收](feature-acceptance.md) 和 [优化调查](performance.md)。执行状态以对应 Linear 任务为准。

2026-10-08 最终核对：XW-69/70/76/77/78/80/81/82 均 Done，没有开放的 Muses Bug 标签任务。代码 `e44a058` 的[完整 CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37874847384)通过 886 项测试/120 个套件、元数据和预览包装；未验原生/系统/账号条件仍不算通过。

| 后续修复 | 范围 | 分析与验证 |
| --- | --- | --- |
| XW-76/77 | 异步准备/目录取消，以及空 Search query 打开的真实目录详情 | [来源报告](source-state-acceptance.md) |
| XW-78 | 旧异步磁盘写入撤销/替换顺序与冷读持久完成 | [CI 回归](source-ci-regression.md) |
| XW-80 | 已聚焦字体搜索的方向键、Return、查询重置与取消 | [原生焦点跟进](settings-focus-followup.md) |
| XW-81 | 隐私清除后撤销并淘汰旧分区对象，恢复新快照冷读，保持其他账户/层/语言隔离 | [缓存恢复](source-cache-recovery.md) |
| XW-82 | 空历史范围复用已有横向 picker；常规与 840×804 真实渲染 | [草稿/历史报告](playlist-flow-followup.md) |

## XW-69：旧 Desktop 设置入口指向错误分类

`SettingsPage` 的 General 分支拥有 `DesktopSettingsView`，提供 Menu bar、Mini player 和 Desktop lyrics。`SettingsCategory.desktop.destination` 仍指向 Appearance，因此旧保存值、类别请求及 `BrowseRouteSnapshot` 解码会指向没有这些控件的页面。

修复限于把旧分类重定向到 General。普通设置入口、十个一级分类、主题/字体、播放服务和桌面窗口生命周期均保留。已更新两处过时预期，并增加真实 JSON 旧路由的解码与 Home → General → Appearance 历史回归。修复前该回归出现三个失败，修复后相关 73 项测试通过。

隔离原生实例已确认 General 拥有上述控件，Appearance 拥有主题、字体和分页选项。该原生检查证明当前控件归属；旧路由的解码与历史语义由专门回归证明，不能把普通 Settings → General 当作完整旧入口实测。

完成门槛：代码/测试提交、原生所有权证据、临时偏好恢复和实例清理。大范围 Settings 键盘与弹窗仍属 XW-71。

## XW-70：CI 编译器表达式推断超时

同步 `d681186` 后，实际 [CI 37745452702](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37745452702) 在 Swift 6.3.3 的 `CollectionPage` 分页 ScrollView 表达式失败。本机 Swift 6.4 编译正常。`3fad018` 提取分页容器、歌曲行和行标签为独立表达式，保留原修饰器、行身份、菜单、分页状态及元数据任务。

[下一次 CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37746196383) 已通过该处编译，随后在 `PodcastContinueShelf` 的 flatMap/filter/prefix 表达式出现同类错误。`b17ff8b` 拆为有明确类型的全集、资格/去重筛选和 12 项截取，保持原顺序与条件。相关 100 项测试通过。

原生隔离版的 `test` 506 项歌单分页已观察到 1/21 → 2/21 → 1/21，第二页从第 26 首开始；正常标题、导航与 PlayerBar 保留。分页开关由用户开启后核对，不把工具未生效的点击当作通过。该实例包含表格和 Settings 修复，尚不包含后续纯播客表达式拆分；播客拆分须由对应测试及实际远端工具链检查。

完成门槛：原有 CI 全阶段成功，包括 Swift 测试、App Intents、包装。保留 macos-26 runner；不提高部署门槛、跳过测试或扩展产品行为。

## 已完成缺陷的复用

XW-53 已完成紧凑窗口导航/Queue/PlayerBar边界及标题修复，用户确认音量 0%/100%、四次 Left 到 80% 与 Escape。XW-54–61、63–68 等任务的具体原生证据继续保留，详见 [64 区域对照表](../ui-ux-acceptance-reconciliation.md)。不重复创建其已解决缺陷，不从单个通过状态推导完整交叉矩阵。

XW-62 的评论/回复请求竞争已修复，状态 In Review。真实非空回复与分页因现有账号返回 `insufficientPermissions` 受限；这属于实时验收边界，不是新增未实现代码。保留独立请求、取消、身份和晚到响应回归，不启用 Cookie 旁路或扩大权限。
