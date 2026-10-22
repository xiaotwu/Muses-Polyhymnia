# 多轮工作整理：2026-10-21

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
