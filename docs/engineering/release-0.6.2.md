# Muses 0.6.2 发布记录

2026-10-21，用户要求汇总专门对话的提交并发布修复小版本，现准备 `0.6.2`，build `20261021.2`。范围为 [XW-106／PR #15 的 Finder 启动播放修复](playlist-playback-runtime-061.md)，以及最终包冷播放门槛发现的 [XW-107 管道进度修复](playlist-pipe-progress.md)，不重新开启其他验收或 XW-74。

## 修复来源

PR #15 已合入 `cf22b0ab64cbe4626067837b66e952030eccf505`。修复固定摘要下载／打包／签名 Deno 2.9.7，通过包内绝对路径传给 yt-dlp，并将缓存保持在对应应用 namespace；只有 Deno helper 获得 JIT entitlement。未修改播放引擎、队列或资料结构。

专门对话的精确 PR head `749d820` 已通过 [完整 CI 39676388510](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/39676388510)：1009 项常规报告、14 项发布检查、独立磁盘恢复、Release／元数据及签名预览打包／上传。真实 Liked 的时钟、暂停恢复、上下曲、534 项队列顺序及用户听到音乐的确认见原记录，不把这些旧候选结果当成本轮最终分发包已经验证。

## 本轮发布门槛

首轮版本提交 `2e56eca` 的 [完整 CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/39681182839)、签名公证、Gatekeeper、完整包一致性和签名更新源离线检查通过，但真实冷媒体 Play All 仍出现 Retry，因此未发布。该成品和失败证据保留；新增修复必须重新构建、签名公证及实际验收，不能沿用旧 CI 或包验收结论。

版本提交的完整 CI、最终 Developer ID／hardened runtime／嵌套代码与 Deno JIT 验证、应用及 DMG 公证装订、Gatekeeper、ZIP／DMG 内容一致性、最终包隔离真实歌单播放，均须实际通过后再发布。

签名更新源须保留旧条目并逐字段核对；公开版本安装包先发布并回读摘要，再切换更新源。家族仓库随后仅聚合已经公开且字节一致的资产，官网默认最新稳定版入口继续沿用。

当前仍为发布准备状态。已安装 0.6.1、当前正常资料／偏好、旧修复候选与全部历史证据继续保护，不覆盖既有发布资产，不变更系统设置或音频输出。
