# 当前修复与验收状态

2026-10-08 最终核对。已确认的 XW-69/70/76/77/78/80/81/82 均 Done，Linear 的 Muses Bug 标签下没有开放项。最新代码 `e44a058` 的[完整 macOS CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/37874847384)成功：886 项测试、120 个套件（41.171s），发布配置、App Intents 元数据、预览包装与上传均通过。后续验收记录 `299efbd` 只修改文档；不据此重复已通过的代码测试，也不把 CI 当作完整原生验收。

Linear 以 XW-5 及子任务组织工作，没有独立 Muses Project 对象。仍有 25 项开放：18 In Review、6 In Progress、1 Backlog，包含阶段和协调父任务，不能当作 25 个尚未修复的缺陷。所有源码改动均已推送，无待合并源码。完整产品验收尚未全部通过。

## 已完成的修复

| 任务 | 具体问题与结果 | 证据 |
| --- | --- | --- |
| XW-69 | 旧 Desktop 设置分类指向实际拥有控件的 General；序列化/历史回归与原生归属通过 | [修复分析](repairs.md) |
| XW-70 | 限定 Swift 6.3 表格/播客表达式推断，原有 CI 全阶段恢复 | [修复分析](repairs.md) |
| XW-76 | Home 准备和目录响应保留取消/操作身份，禁止晚到结果更新缓存 | [来源验收](source-state-acceptance.md) |
| XW-77 | 空 Search query 不再隐藏或清除 Home 打开的目录详情，实际集合上下文与历史通过 | [来源验收](source-state-acceptance.md) |
| XW-78 | 旧异步写入不能重建已删除缓存或覆盖新值；冷读测试等待持久化完成 | [CI 回归](source-ci-regression.md) |
| XW-80 | 字体搜索框 Up/Down、Return 和查询重置/取消路径可用；真实原生键事件验证通过 | [焦点跟进](settings-focus-followup.md) |
| XW-81 | 清除已打开的账户 Web 缓存后可重新持久保存并冷读，其他分区保持隔离 | [缓存恢复](source-cache-recovery.md) |
| XW-82 | 空历史范围复用既有横向隐藏视觉标签控件；常规 Light/Dark 和 840×804 真实复查通过 | [播放与草稿跟进](playlist-flow-followup.md) |

此前 XW-53 等紧凑布局、Queue、播放器和歌词修复的具体通过项继续复用。XW-62 评论请求竞争代码已经修复，真实非空回复仍受现有 `insufficientPermissions` 限制，保持 In Review；不扩大认证或制造回复。

## 新增验收与保留边界

| 范围 | 新增实际结果 | 尚未通过 |
| --- | --- | --- |
| XW-71 Settings | 十类设置、真实历史和后台播放；字体指针/键盘选择、即时样本、语言/字号恢复、Help 折叠及 Escape | 当前键盘模式 0 下按钮遍历/原按钮焦点返回、完整辅助功能和实际 macOS 26 |
| XW-72 辅助窗口 | MiniPlayer 生命周期/Pin/快捷键共享播放；真实 LRCLIB 桌面歌词 Light/Dark 和 35.39s 行跳转；空态/拖动/释放；菜单栏 Escape 与共享音量 | 物理控件交接/完整焦点、真实未同步歌词、系统 Dark 菜单栏及外部矩阵 |
| XW-73 来源 | 匿名 Home 加载/缓存/过期恢复、真实目录上下文；New 图书馆上下文及诚实未解析空态；取消与缓存修复 | 指针 Retry 失败恢复、非空图书馆目录、成功身份匹配个性化 Home等条件 |
| XW-79 草稿/历史 | Dark group/history、非法整数保留草稿与 Cancel、真实 test 请求 pending/error Cancel；一个公开来源 108 项只读选择/Back/确认取消，无 Import；取消检查点 27 表一致 | 原 test 源当前返回 playlist does not exist；真实 canonical-tail 选择/可播放/自然 stop/wrap 未验 |
| XW-74 性能 | 真正指针滚动、CPU/RSS与保留 trace；A2 偏差收窄到第七次输入，后续同进程序列未重现 | 完整 AX 对照无效，指针帧记录未完成；没有因果归因、FPS、能耗或泄漏改善结论 |
| XW-75 App Intents | 两项已有能力的元数据与声明核对 | 安全隔离的真实系统调用条件尚不足，保持 Backlog |

详见 [Settings](settings-acceptance.md)、[辅助窗口](auxiliary-acceptance.md)、[辅助焦点/真实歌词](auxiliary-focus-followup.md)、[滚动报告](scrolling-performance.md)、[64 区域对照](../ui-ux-acceptance-reconciliation.md)。没有新增已批准但完全缺失的产品功能；剩余主要是具体原生/来源/系统验收条件。

## 恢复与继续

所有本轮拥有的应用和窗口均已退出，完整临时偏好已恢复，专用 data/cache 已清理，工作区/运行锁已释放。源 SQLite/WAL/SHM、完整源偏好及正常应用文件校验一致。副本会话更新时间和 JSON 编码顺序变化已独立审计；队列五项解码后的值与顺序相同，不是新增数据 Bug。恢复后的副本另行验证 27 表、schema 与完整性一致，不抹去此前真实运行差异。

最后阶段 Mac 锁屏，AX/截图及正常原生退出不可用；在准确 UID、唯一 bundle、执行文件和启动时间核验后，仅对暂停的专用实例发送 SIGTERM，没有 force-kill。退出后恢复独立偏好与原始物理域缺席，保留私有证据、只读备份和不运行的签名候选作为后续材料。

**下一项本地验收是尾曲自然结束。** 等待用户手动解锁；优先使用已经存在的分页/列表等后台原生路径，必要前台输入须有明确授权。下一阶段使用新隔离 namespace/data seed，保留真实 canonical occurrence/集合上下文，不以显式 Next、单结果 Search 或合成时间替代自然 stop/wrap。已通过的编辑、公开预览和布局流程不重做。

实际 macOS 26、完整 VoiceOver 与用户延期的 OS 矩阵、非空授权订阅、评论权限、身份匹配 Personalized Home及安全真实 App Intents条件仍保持未验。只允许 `test` 的已授权修改/Pull/恢复；不执行 Liked、破坏性历史/group操作、远端写入、权限或 OS/输出变化、发布安装。22 个历史对话已归并且可恢复归档，当前有未完验收的执行对话继续保留。

第二轮记录位于 `~/.muses/tmp/engineering-oct08/round-2/`。完成标记表示当前可执行子集已清理并释放资源，不能代替人类解锁、前台授权或完整父任务通过。
