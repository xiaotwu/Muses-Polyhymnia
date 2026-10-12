# Muses 0.6.0 发布记录

2026-10-12，用户批准将当前大更新发布，剩余验收、增强和优化转为发布后工作。[Muses 0.6.0](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.0) 已公开发布并设为最新稳定版，签名自动更新源已切换。公开下载返回成功，远端资产摘要、标签指向及下载后的 feed 验签均通过。

- 发布源码：`ec6d0ecdbc5849f548879c54489c6eec05a59abb`。
- 版本：`0.6.0`，build `20261012.1`。
- 要求：macOS 26 或更高版本，Apple Silicon（arm64）。
- [产品更新说明](../release-notes-0.6.0.md)。
- [发布提交的 macOS CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38306575438) 全阶段通过：14 项发布检查；常规 Swift 运行报告 901 项测试、123 个套件、55.523 秒（包含 opt-in 跳过项）；独立磁盘恢复为 1 项测试、1 个套件、0.100 秒；App Intents 元数据、预览打包与上传通过。

## 资产与验证

正式应用和 DMG 分别通过 Apple 公证并装订票据。应用、Web Home helper、Sparkle 和两份 yt-dlp 完成签名验证；应用和 DMG 通过 Gatekeeper 评估。ZIP 解包与只读挂载 DMG 后，应用主程序、helper、Info.plist 一致，完整代码签名与票据复验通过。

| 资产 | 字节数 | SHA-256 |
| --- | ---: | --- |
| [Muses-0.6.0.dmg](https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.6.0/Muses-0.6.0.dmg) | 93,318,466 | `329f43928ddcdbf962c4ddb2a9984cca367e1f50305f6f666865ced565d4a3bf` |
| [Muses-0.6.0.zip](https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.6.0/Muses-0.6.0.zip) | 93,764,789 | `4790203631e9a2c4247ac6bb2423b356fae0714c0343d6602a3ac605167897ef` |

`SHA256SUMS` 与两种安装包一同发布。GitHub 上传资产的大小及服务器端摘要与本地成品一致。正式包继续使用原有 OAuth 构建配置和更新公钥；不包含用户账户令牌、资料库或验收夹具。

自动更新源保留完整的 0.5.11 条目（build `20261001.5`，最低 macOS 14），并将 0.6.0 放在首条（最低 macOS 26）。旧条目的全部 XML 字段与已验证签名的原始 feed 一致。新 feed 整体签名和当前 DMG 的 Ed25519 签名均通过应用内置公钥验证，版本顺序、大小、URL 与系统要求验证通过。14 项发布配置/验签测试通过，独立只读审阅未发现发布阻碍。

## 发布后的接续范围

Linear 保留 24 项开放工作：18 项 In Review、6 项 In Progress，包含父任务与协调项。XW-83/84/85/86/87/88/89 维持 Done；这次发布不将未完成的验收条件标为通过。

按 [当前状态](current-status.md) 接续，优先 XW-75 原串行键盘路径，再处理其余 Settings、辅助播放窗口、真实来源状态、评论回复、无障碍与性能测量条件。完整 macOS 26 原生呈现、VoiceOver/显示组合及特定账号/来源覆盖仍以各任务的实际证据为准；CI 与签名、公证不能替代这些交互验收。

本次构建使用独立工作目录，未安装到正常应用。正常 `/Applications/Muses.app` 和原有 `build/Muses.app` 的主程序及 Info.plist 哈希保持不变。
