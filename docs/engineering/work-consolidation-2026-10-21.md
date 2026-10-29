# 多轮工作整理：2026-10-21

2026-10-28 磁盘与缓存收尾：两次明确确认的69个旧缓存／克隆／已验副本已清理，62条旧生成注册按路径撤回；两个处置区间APFS实测空闲增量合计60.98171GiB。既有Storage窗口只读显示434.63GB已用／559.98GB空闲、System Data181.61GB；未确证此前约900GB分类的成因，Docker稀疏磁盘和用户数据保留。[PR #25](https://github.com/xiaotwu/Muses-Polyhymnia/pull/25)已合入`2800808`，功能源码`f9d80a9`；精确head `7be355c`的[完整CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/40815358119)通过1,142项／153套件（9项明确条件跳过），另有严格线程／磁盘恢复／50项发布检查及签名预览打包。XW-131／132按源码与组件证据Done：普通暂停缓存／预下载共享默认2GiB，搜索64MiB、Home128MiB、公共目录200MiB按family聚合，保护活动文件与有效账号fallback，去除无读取者封面重复写入；不转为新原生设置／播放／回收证明。截图残留另已备份／保留rollback后精确清理菜单栏8对、Spotlight41键并独立读回，正常Muses／ManualShortcut及其他项保留；23旧BID的逐应用TCC命令成功仍非界面清除证明，未注册标识一次失败后不重试，通知28旧ID留原生逐应用重设核验。新批已收窄为1556残留＋23旧APP＋2完成编译缓存，共1581项／7.23761GiB分配量；APP与完整SQLite资料及1492逻辑偏好已归档并独立核对，约3.83603GiB恢复档保留，等待本批新永久确认；两pause APP和六关联依赖原位保留。135原生输入、正常资料、共享依赖、既有Shortcuts及暂停trace保留。Linear六事项与两项目文档已同步回读：118项、95 Done、原23项开放（17 In Review、6 In Progress），历史与父子关系保留。XW-74测量／Premium／Erato暂停与**暂不发布**保持，当前后台清理收尾后再开前台对话。[完整记录与边界](disk-hygiene-and-cache-budget-2026-10-28.md)。

2026-10-28 后台余项收尾：精确复用隔离 Release `20261026.3`，新增播放中 Clear 与 Automatic→Data saver 重载两格；同曲重载后 Pause／时钟分别推进1:42→1:51、2:35→2:48，暂停2:50后恢复Automatic，正常Quit与新PID冷恢复保留检查点。七份完整27表独立审计保留535曲目、1064成员、40旧事件及534队列occurrence／顺序／完整JSON；仅当前曲实际首次Play的计数11→12／lastPlayedAt及状态／ORM／位置微差单列，21表同值。静音时钟不代表可听或无缝声音；重复pending reload仍仅有组件证据。无新产品缺陷、源码修改、构建或重复CI。两候选退出，三自有路径及注册已清理；原清理中断未写出成功回执，未重跑删除，独立只读复核确认62项资料归档／623项旧应用ZIP／原始库／135审计输入保留、初始偏好严格回读、五保护根一致。9个Linear事项及两份项目文档更新回读，历史／状态／父子关系保留；项目116项、93 Done、原23项仍开放（17 In Review、6 In Progress）。已识别的可靠后台格完成，按用户指示新开前台核验对话，优先列头／分页、书签输入、EQ删除／实体Escape和闭窗Settings／诊断预览；账号、设备、实际macOS26及完整可访问性条件仍另需前提。XW-74测量／Premium／Erato暂停与**暂不发布**保持。详见[10月28日验收与收尾记录](playing-reload-acceptance-2026-10-28.md)。

2026-10-26 第五轮后台接续：补齐非零缓存摘要读取失败／Retry、已入库歌曲 Library→公共目录→Library 搜索和840×804紧凑Dark历史视图。确证并修复 [XW-130](https://linear.app/xiaotwu/issue/XW-130)：清缓存将暂停1:11重载为0:00，退出后保存约1ms；冻结源码`d7bea1b`保留现有检查点，28项定向测试与独立审查通过。隔离Release `20261026.3`实际验证Clear、Automatic→Data saver→Automatic、正常退出及新PID冷恢复均保留1:11；播放中／重复加载仅有组件测试证据。新旧各5份快照核对，535曲目／1064成员／40事件及534队列语义保留；状态与ORM差异单列。3个候选退出，完整归档、两键偏好严格回读及22个自有路径清理已独立复核，五保护根不变。[PR #24](https://github.com/xiaotwu/Muses-Polyhymnia/pull/24)已合并为`84d0393`，完整CI通过（1,118项／151套件，9项明确条件跳过；严格线程、磁盘恢复、50项发布检查和签名打包成功）。12个Linear事项及两份项目文档已更新回读；项目116项、93 Done、原23项开放（17 In Review、6 In Progress）；原23项矩阵、XW-74／Premium／Erato暂停与**暂不发布**保持。详见[本轮修复与验收记录](populated-cache-reload-2026-10-26.md)。

2026-10-26 第四轮后台接续：修复媒体缓存删除失败却显示Zero KB的 [XW-129](https://linear.app/xiaotwu/issue/XW-129)，[PR #23](https://github.com/xiaotwu/Muses-Polyhymnia/pull/23)已合并为`74c8782`，冻结验证源码`bebadc3`。22项定向检查与精确源码完整CI通过（1,116项／151套件，9项明确条件跳过；严格线程、独立磁盘恢复、50项发布配置及签名打包通过）。隔离Release `20261026.2`真实确认0500删除失败保留53 KB并提示错误、0700原生重试确实删除，以及无前次摘要的0100读取失败显示Unavailable／原生Retry恢复。另补空Music Videos自身Open Search入口和test专属受控歌曲非空Year／Genre显示；不扩称元数据Save、真实来源资料或排序通过。9份数据库／27表独立审计保留535曲目、1064成员与534队列语义；22表同值，5表状态／ORM变化及位置浮点微差单列。三个候选退出，归档及两键初始偏好回读完成，14个自有路径清理，五保护根保持。8个Linear事项及两份项目文档同步回读；项目115项，92 Done，原23项开放（17 In Review、6 In Progress）。已通过格不重复计入，无效输入路径不反复尝试，XW-74／Premium／Erato暂停与**暂不发布**保持。详见[本轮修复与验收记录](cache-clear-and-metadata-2026-10-26.md)。

2026-10-26 第二轮后台接续：修复导入 Songs 丢失已保存播放次数／年份／流派的 [XW-128](https://linear.app/xiaotwu/issue/XW-128)，[PR #22](https://github.com/xiaotwu/Muses-Polyhymnia/pull/22)已合并为`0104420`，产品与验证源码`a8e95c5`同值。旧实现5项断言红复现，22项相关测试及完整CI通过（1,111项／150套件，9项显式跳过；严格线程／磁盘恢复／发布配置／签名预览均成功）。新隔离Release `20261026.1`实际确认两首歌曲Plays由错误0恢复为原存储1，并新增Plays、Date Added菜单升序验收；既有排序、分页、EQ、Home等通过格不重复计入。535曲目／1064导入成员／40事件保留，534队列语义与顺序保留，21业务表精确同值；实际状态与ORM差异单列。原生分页开关、列头／降序和多书签输入仍无有效后台证明。全部候选正常退出，应用623项／资料126项完整归档，14个自有路径清理并独立核对，五保护根无变化。7个Linear事项及两份项目文档已同步回读；项目114项，91 Done，原23项开放（17 In Review、6 In Progress），既有暂停保持。**暂不发布**。详见[本轮修复与验收记录](imported-song-metadata-2026-10-26.md)。

## 当前接续 — 2026-10-23

PR #18 已合入 `c8c7863`，PR #17 已合入 `02ebc7d`，PR #16 因真实祖先进入 main 自动 Merged。修复与新 build `20261023.3` 的签名公证／整合原生证据见 [RC 回执](release-candidate-2026-10-23.md)。精确 head CI 40032998389 全通过；XW-107／118／119／120 Done，父级矩阵另保留。家族仓库仅跟进已合并 child main 引用；用户明确暂不发布。

以下是当时的整理与未完成状态，作为历史保留，已由上述新结果接续。

2026-10-22 接续：[XW-107 冷解析修复与新候选结果](cold-resolution-timing.md#current-result--2026-10-22)已补入 PR #17：同版本目录式解析运行时消除启动延迟，9/9固定冷样本通过，1,077项完整测试及34项打包／7项严格线程检查通过。正式资料、共享构建、旧候选和证据完整保留。精确提交CI单独跟踪PR检查；PR继续Draft，最终签名公证／整合与发布门槛尚未关闭，不更新父仓库到未合并的子模块引用。

## 已保存的修改

核对本仓库、家族仓库和五个相关对话后，未发现未提交的源码修改。macOS main 已包含 0.6.1 后续修复和 0.6.2 准备提交 `2e56eca`。以下增量已经分别提交并推送，保留原验证证据：

- [PR #16](https://github.com/xiaotwu/Muses-Polyhymnia/pull/16)，`codex/playlist-pipe-progress` / `dfe0ae6`：解析管道读取与恢复错误传播，仍开放。
- [Draft PR #17](https://github.com/xiaotwu/Muses-Polyhymnia/pull/17)，`codex/playback-backend-refactor`：以 `275bd62` 为本轮核对的源码/证据检查点，包含解析契约、libmpv 后端、依赖打包、CoreAudio 格式修复、动态库驻留和下一首预解析交接。三个协作对话的修改已由协调对话整合提交，无需再次复制或重复提交。

本轮仅提交工作归属和整理文档；main 不提前接入待验收的播放后端。历史验收分支和独立 worktree 保留，不重置、不清理。

## 仍需处理

公开播放已有真实连续播放、暂停、seek、缓存重播与已准备下一首的限定证据。冷解析仍出现约 20 秒超时，另有后台约 11.9 秒成功和独立 runner 约 8.9 秒成功的对照；原因未定位，不能写成稳定冷启动。详细记录保存在 PR #17 分支的 `docs/engineering/native-playback-backend-refactor.md` 和 `current-status.md`。

0.6.2 继续暂缓，PR #17 保持 Draft，会员音质 deferred，XW-74 继续暂停。整理提交不替代原生验收、正式发布或恢复执行授权。正式应用、正常资料/偏好、凭据、共享构建和旧证据保持原有保护边界。

## Linear 唯一工作项目

[Muses](https://linear.app/xiaotwu/project/muses-5e747ca2af19)（`P-XW-2`，UUID `c2f9c252-e1d1-4210-bbd5-15a5366b9d28`）覆盖全部 Muses 平台及家族网站/发布中心。

103 个已有 Muses Issue（XW-5 至 XW-107）已迁入并完整回读，父子关系保持。已有独立 Linear 文档均属其他项目，没有待迁移的 Muses 独立文档。此后查询、创建、更新和验收均显式指定本项目；不会因迁移改变现有 Issue 状态或扩大工作范围。
