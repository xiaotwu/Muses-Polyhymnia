# 单曲真实视频画面与 seek — 2026-10-21

完成本轮 XW-73 后，再推进 XW-26 的这一独立小节。使用 `com.muses.acceptance.video-seek-oct21`、build `20261021.2601` 的全新可写资料副本，复用本轮已核对的修复 Release；未修改视频／播放源码。环境为 macOS 27.0.1、Light、1280×804pt，初始应用音量 0、原曲暂停在 0。

## 实际操作与接受边界

只使用既有 `75wwBVDPeyY`，即 Punishing: Gray Raven / Sugar Time。PlayerBar 打开真实悬浮视频，随后用“返回主窗口”进入同一视频的主窗呈现。来源 URL、标题与身份相符，没有切换其他视频或登录。

点击官方播放器 Play 后，首次捕获为黑色初始帧／0:00，不作为成功画面。稍后控件显示 0:41 / 3:28、Pause，真实画面包含演出图像及当时字幕；通过控件暂停，保存了实际帧。视频自身的 Mute 随后明确切为静音，应用返回时仍显示音量 0%。

辅助功能直接写入 Seek slider 没有改变时间，不计为 seek 成功。根据当前真实截图，点击可见时间轴约 15% 处，播放器从 0:41 跳到 0:31，滑块、画面与字幕同步变化。再短暂 Play／Pause后，用自身“关闭视频”返回 Home；PlayerBar 是同一首、显示 0:32 / −2:55 和 Play，说明原生音频仍暂停。队列显示当前集合 531 项、Up Next 0；未操作下一首、循环或随机。

这一结果补齐这首录音的真实帧、可见时间轴点击、seek 后续播／暂停及同曲位置承接。它不替代其他视频来源、拒绝嵌入、来源失败／Retry、设备／睡眠唤醒、完整焦点／辅助功能或实际 macOS 26 的剩余矩阵。没有重做已接受的章节／Escape 矩阵，评论／回复继续完全退休。XW-26 保持 In Progress。

## 停止后的资料核对

候选正常退出，各自 20 项初始 typed 偏好恢复。停止备份 quick_check 通过：

- 仍为 531 Tracks／6 Events；Track UUID／YouTube ID 及全部原有资料保持。只有当前 `75wwBVDPeyY` 的播放计数 0→1、lastPlayedAt 和 ORM 版本发生预期变化。
- 队列 531 个 occurrence 身份、Track 身份、顺序、集合、Up Next、groups、history、repeat／shuffle 及全部解码 JSON 与原副本一致。
- 队列保存位置 0→31,555.064459 ms；新会话的当前位置同为 31,555.064459 ms，且属于同一 Track。生命周期、会话和 ORM 写入单独保留，不声称资料库字节不变。
- 正式应用完整清单、正常资料原始文件／47 偏好、原始只读种子、旧证据及共享 Release 保护核对通过。

实际画面、AX、资格及停止检查点保留在 `~/.muses/tmp/engineering-oct15/search-paging-returns-oct20/`；本轮没有系统设置、输出设备、账号授权或远端写入，也没有启动 XW-74。
