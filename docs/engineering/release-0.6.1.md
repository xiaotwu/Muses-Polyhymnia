# Muses 0.6.1 发布记录

2026-10-21，按用户授权发布 [Muses 0.6.1](https://github.com/xiaotwu/Muses-Polyhymnia/releases/tag/v0.6.1)，build `20261021.1`，已设为最新稳定版并切换签名更新源。最低 macOS 26，Apple Silicon（arm64）；[产品更新说明](../release-notes-0.6.1.md) 汇总 0.6.0 后的修复及评论退休决定。

## 源码与 CI

- 标签及实际发布源码：`52d104ce7d06410579afa8deae7db77cde360db6`。
- [PR #14](https://github.com/xiaotwu/Muses-Polyhymnia/pull/14) 已合入 main `de5cfa697f2ed918870c6ac0dea7567193596fee`，与标签的 whole tree 完全相同；分发包来自该精确已验版本提交，没有重编其他来源。
- 精确标签源码的 [完整 CI 39568128485](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/39568128485) 全部 11 阶段通过：1007 项常规 Swift 报告／135 套件（62.142 秒，9 项既有 opt-in 跳过）、14 项发布检查（8.976 秒）、独立磁盘失败恢复 1 项（0.100 秒）、Release／App Intents 元数据／预览打包与上传。
- 本地 14 项发布检查通过（1.574 秒）。版本变更仅更新默认版本、打包及 CI 配置和文档，产品修复已在先前定向原生记录中接受。

## 分发资产与更新源

应用、helper、Sparkle 嵌套代码及两份 yt-dlp 均以原 Developer ID 团队 `9URWGD9Q86` 签名，hardened runtime 和时间戳通过。主程序为 arm64，实际 Mach-O 最低系统为 26.0。应用与 DMG 均获 Apple Accepted、装订票据并通过 Gatekeeper 的 Notarized Developer ID 评估。

- 应用公证：`7df532ea-5932-49a4-97fc-c582fefa2261`。
- DMG 公证：`1fd696c3-a4e6-4cbf-9cda-21ebe07a34af`。
- ZIP 解包及 DMG 只读挂载后，应用完整文件字节、模式、符号链接清单与正式成品一致；重新验证严格代码签名及公证票据通过。
- 仅复用已发布应用的项目 Desktop OAuth 构建配置及更新公钥，没有复制用户账户令牌、cookie、资料或验收夹具到分发包。
- DMG 工具初次选中了系统 Python 3.9，无法安装既有固定依赖；改用独立 Python 3.14 虚拟环境后成功。未修改依赖版本或产品代码，失败记录保留。

| 资产 | 字节数 | SHA-256 |
| --- | ---: | --- |
| [Muses-0.6.1.dmg](https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.6.1/Muses-0.6.1.dmg) | 93,338,392 | `c05bbd393bcbf4544ab9146792b66743f25cfa95d63dd2e1fcbff1af32e0cbb5` |
| [Muses-0.6.1.zip](https://github.com/xiaotwu/Muses-Polyhymnia/releases/download/v0.6.1/Muses-0.6.1.zip) | 93,814,782 | `743cd26464fb91d2dfd2201a9964c9a6f47aae1a25ee1ce38e336f038ed9e436` |

`SHA256SUMS` 一同发布，三个资产的 GitHub 大小／服务器摘要与本地一致，公开 URL 实际下载后字节再次一致；标签解析为上述精确已验提交，latest 稳定版回读为 v0.6.1。随后才替换稳定 appcast，公开下载的 feed 与成品一致，并用应用内置公钥验证整体 feed 和已下载 DMG 的 Ed25519 签名。

更新源顺序为 0.6.1／0.6.0／0.5.11，旧两条 XML 全部字段保持，0.5.11 最低 macOS 14 的兼容条目继续保留。没有在正常安装上执行自动升级；签名链及公开分发验证不替代安装后的全部交互矩阵。

## 最终包烟雾检查与保护

由正式成品派生独立 `com.muses.acceptance.release-061-oct21` 候选，移除 OAuth、深链接和正常更新源后重新签名；主程序 `__text` 与正式成品一致。本机 macOS 27.0.1 实际接受 Home／暂停与音量 0、歌词匹配默认模糊／切换精确保留输入和提示、自身 Close 返回及歌词抽屉关闭、General／About 画面与 0.6.1 版本显示。没有执行 Play、Apply、导入、账号授权或系统设置变更。

第一次退出后的界面读取返回了重新打开的 Home；第二次退出改以 inventory 与独立进程缺席核对，不再读取并唤起候选。两次启动均纳入停止审计：531 Tracks／6 Events、全部 Track 行、七项队列 JSON 解码语义、当前曲／索引及位置 0 ms 保留，正常退出的保存时间／ORM 写入单列。20 项原始偏好按值和类型恢复；候选、namespace、偏好及已替代 Python 3.9 环境经过归档解压逐项核对后清理，当前正式分发包及编译产物保留。

没有替换或启动 `/Applications/Muses.app`。其正式 0.6.0 的完整 207 项清单、原始只读种子及 18 组既有证据完整保护。正常资料在本轮开始后观测到保存时间／ORM、等价队列 JSON 编码和四项偏好变化；来源未归因，未回滚。独立复制并审计该新状态后继续保护：531 Tracks／6 Events、队列身份／顺序及解码内容保留，47 项最新偏好与该检查点一致。不将这些变化写成全程字节恒等，也不归因于本轮未执行的正常应用操作。

## 后续范围

本轮实时 Linear 共 23 项开放（17 In Review、6 In Progress），无开放 Bug 标签任务。XW-73 其余取消／Retry／来源与账号条件、XW-26 其他播放及持久化路径、完整 VoiceOver／实际 macOS 26／其他设备矩阵继续保留。XW-74 未恢复，没有采样或性能优化结论。

家族仓库只聚合已公开的三个资产并验证来源摘要，不重建或改变字节。官网 Mac 默认下载改用该平台的 `/releases/latest`，另设 Release history 到版本列表；安装说明保留 macOS 26／Apple Silicon 要求和 0.5.11 兼容入口，避免默认入口固定在某个版本。
