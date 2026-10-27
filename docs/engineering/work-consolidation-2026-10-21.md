# 多轮工作整理：2026-10-21

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
