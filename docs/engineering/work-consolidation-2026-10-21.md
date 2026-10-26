# 多轮工作整理：2026-10-21

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
