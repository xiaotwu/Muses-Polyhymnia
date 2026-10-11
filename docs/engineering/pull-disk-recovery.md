# Pull 真实磁盘写入失败与恢复

2026-10-11，XW-84 的实际持久化错误分支通过。新增回归使用真实磁盘 SwiftData 容器和生产 `applyPull` 保存闭包；应用源码保持 `3b44632` 的既有实现，没有再注入 Swift 保存异常。

## 方法与隔离

测试在 `~/.muses/tmp/pull-disk-test-<UUID>/` 创建仅用于本次验证的 0700 目录及 SQLite 库。普通测试运行默认跳过该用例；CI 在全套测试后以单独进程、唯一 filter 和显式环境开关执行，并设置两分钟上限。用例在修改进程状态前核对 filter、串行运行参数和当前测试身份，拒绝重复运行参数。

在同步 `applyPull` 窗口中，将该测试进程的 `RLIMIT_FSIZE` 软限制暂时设为 0，暂时忽略 `SIGXFSZ`；硬限制不变。退出窗口时先恢复原限额，再恢复完整信号设置，之后才断言、审计和重试。父进程通过 pipe 收集输出，其限额保持原值。这利用的是操作系统实际拒绝文件写入的路径；Apple 对 [文件大小限额与写入失败](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getrlimit.2.html) 有明确说明。

使用合成歌单数据验证本地事务，不访问账号、Keychain、正常资料库或远端服务。该机制测试 `EFBIG` 导致的 SQLite 写入错误，不能推广为磁盘耗尽、硬件故障或所有 I/O 错误类型。

## 验证结果

本机 macOS 27.0.1（26A434）上，SwiftData 的真实保存返回 `NSSQLiteErrorDomain` / `778`（`SQLITE_IOERR_WRITE`），错误中的路径精确指向自有测试库。最终版本的独立用例通过，完整测试运行 0.041 秒。

提交 `8a58f7b` 的 [完整 CI 38149867942](https://github.com/xiaotwu/Muses-Polyhymnia/actions/runs/38149867942) 也已通过。常规运行报告 896 项测试/123 个套件（53.867 秒），其中跳过此 opt-in 用例；独立进程随后真实得到错误 778 并完成恢复，1 项/1 套件通过（0.144 秒）。8 项发布检查、App Intents 元数据、预览打包和上传均成功。

- 失败前后，通过独立只读 SQLite 连接比较 Import、Item、Revision、Track 四张表所有已提交行的列类型与读取值，结果一致；另用 fresh ModelContext 核对 Local 身份/顺序、Base/Remote 指针、lastSyncedAt、63 条完整修订、Track 与关系均保持原状，刷新通知为 0。
- 解除限额后，同一服务、同一 preview 和同一 resolved snapshot 重试成功：新 Local/Base、一个 beforePull、一首新 Track、修订剪枝至 50 条，恰好一次刷新通知。
- 释放第一组对象后，在同一测试进程中新建 ModelContainer 重开文件，持久化结果相同。这不是应用冷启动验收。
- 两项既有 Pull 原子保存/受控失败回归仍通过；8 项发布配置检查通过。父进程限额一致，自有测试目录零残留。误用 suite 级 filter 的负向调用在夹具创建与限额修改前按预期拒绝，退出 1，没有进入 I/O 故障窗口。

复现命令：

```sh
swift test --no-parallel --filter PlaylistPullPersistenceTests
MUSES_PULL_DISK_FAILURE_TEST=1 swift test --skip-build --no-parallel --filter PlaylistPullPersistenceTests/diskFailureThenRetry
```

Core Data 会为这个预期故障输出 I/O error 日志；通过标准仍是测试断言和退出状态。测试代码见 [PlaylistPullPersistenceTests](../../Tests/MusesTests/PlaylistPullPersistenceTests.swift)，CI 的独立步骤见 [build.yml](../../.github/workflows/build.yml)。私有原始日志和进程审计位于 `~/.muses/tmp/engineering-oct08/round-4/root/`。

## XW-84 剩余范围

原生 Pull Preview 中的错误文案、已解决冲突草稿保留和点击 Apply 重试仍需实际 UI 验收，因此 XW-84 保持 In Review。生产预览需要可读取的现有 OAuth 会话、匹配的频道身份和完整 Data API 快照。历史匿名 yt-dlp 导入失败不能证明该路径不可用。

这项回归只接受 Pull 保存错误与恢复；其它元数据保存、远端 Push/manage、原生应用冷启动和完整 OS/VoiceOver 矩阵保留各自范围。
