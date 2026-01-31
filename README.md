# Coriander Player 二改：Material You 风格的本地音乐播放器

\*\*该播放器发行版已经附带桌面歌词组件。

- [desktop_lyric](https://github.com/Ferry-200/desktop_lyric.git)

## 安装

通过项目内的ps1来自动编译，默认只支持Windows版

## 其他平台支持

- MacOS: [https://github.com/marscey/coriander_player/tree/macos-platform](https://github.com/marscey/coriander_player/tree/macos-platform)
- Linux: [https://github.com/Sh12uku/coriander_player_linux]

## 软件内快捷键

页面中有文本框且处于输入状态时会自动忽略快捷键操作。如果要使用快捷键，可以点击输入框以外的地方，然后再次使用。

- Esc：返回上一级
- 空格：暂停/播放
- Ctrl + 左方向键：上一曲
- Ctrl + 右方向键：下一曲

## 提供建议、提交 Bug 或者提 PR

我正处于学习和适应 Github 工作流的阶段，所以目前不设置太多的要求。你只需要注意以下几点：

1. 如果要提交 Bug，请创建一个新的 issue。尽可能说明复现步骤并提供截图。
2. 如果你提交 PR，由于我正在学习相关知识，可能会在处理 PR 时和你沟通如何操作分支之类的问题。

## 本分支特性

- **降调功能**：集成了 BASS_FX 插件，支持在不改变速度的情况下调节音调（Pitch），或同时调节速度（Speed）。
- **系统级的音量调节**：
- **修复SMTC**：

## 感谢

- [music_api](https://github.com/yhsj0919/music_api.git)：实现歌曲的匹配和歌词的获取
- [Lofty](https://crates.io/crates/lofty)：歌曲标签获取
- [BASS](https://www.un4seen.com/bass.html)：播放乐曲
- [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)：实现许多 Windows 原生交互
- [Silicon7921](https://github.com/Silicon7921)：绘制了新图标
- [coriander_playeri](https://github.com/Ferry-200/coriander_player)：原版coriander_player项目
