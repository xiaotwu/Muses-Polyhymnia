# Home 分页加载状态归属

2026-10-13，先确认 `main` 源码 `9f482a5` 的 [完整 CI](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38483286321) 全阶段通过，再从文档提交 `ce061b1` 独立调查 XW-93。

## 触发与修复

受控 provider 分别暂停旧分页 A 和同名 shelf 的新分页 B。账号切换、推荐来源切换或 cancel/load 后，先返回 A：旧源码拒绝旧内容，却清掉 B 的 loading 标记。More 按钮直接由这个标记禁用，所以重复调用实际产生第三个请求。另一条完整 reload 路径更换 operation，却保留旧 loading/error，导致刷新后 B 无法开始。

原始源码成功编译；六组 A/B 调度和一组 reload 共记录 15 个行为断言失败。旧内容和错误仍被原有 guard 拒绝；没有跨账号内容泄漏或真实网络缺陷结论。

最小修复只调整 `HomeDiscoveryService`：await 后先核对 operation，旧 operation 直接返回，不接触当前标记、错误或内容；reload 更换 operation 时同步清掉失效的 shelf loading/error。当前 operation 仍能清自己的标记、报告失败并重试。同一 operation 内既有 Set 插入门槛继续防重复，没有新任务注册表、播放/队列、存储或 helper/auth 修改。

## 验证

原始两项测试定义、七次调度在修复后保持不变并通过（0.677 秒）。最终专项扩充为五项定义、十八次调度，覆盖：

- 账号、来源、cancel/load 与新旧空/非空响应的十二组 A/B 顺序。
- reload 立即释放旧 marker/error，新同名请求可开始。
- B 先失败并发起重试，迟到 A 不清掉新错误和重试 marker。
- cancel、同意撤销和当前 operation 能力丢失的清理/拒绝边界。

`swift test --no-parallel --filter 'HomeContinuationOwnershipTests|HomeDiscoveryTrustTests|HomeRecommendationTests|HomeFeedRetirementTests|HomeSourceSelectionTests'` 通过 39 项报告定义 / 5 套件（2.476 秒）。参数调度不重复计入报告定义数。扩充期间的 Swift Testing 三组 arguments 声明编译错误已修正，原始失败日志保留，未计作产品行为失败。最终源码/测试指纹经独立只读复审，无阻塞项。

精确 head `d1ab806` 的 [完整 CI 38487746201](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38487746201) 全阶段通过：14 项发布检查（4.459 秒）、917 项 / 127 套件 Swift 报告（62.262 秒，含 opt-in 跳过项）、独立磁盘恢复 1 项 / 1 套件（0.224 秒）、App Intents 元数据、预览打包与上传。[PR #3](https://github.com/xiaotwu/Muses-Polyhymnia/pull/3) 合并为 `bc7d24e`，XW-93 Done。main 的重复 CI 由当前状态接续；源码修复与已验 head 一致。

本次没有真实已同意且身份匹配的账号 shelf 候选，因此不把受控 provider 当作原生或网络验收。XW-73 的真实 Web Home 条件继续开放。正式版 0.6.0 未替换，资料、偏好及 Keychain 保留。

私有证据位于 `~/.muses/tmp/engineering-oct13/xw93-continuation/`：原始源码/测试和指纹、`original-fail.log`、`initial-fix-pass.log`、`expanded-matrix-compile-fail.log`、`focused-pass.log`、最终 owned patch 及 manifest。只清理本轮自建编译产品，保留这些复核材料和正常构建。
