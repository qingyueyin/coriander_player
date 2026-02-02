# Coriander Player 二改：Material You 风格的本地音乐播放器

## 安装

通过项目内的ps1来自动编译，默认只支持Windows版

## 可选：启用软件内创建 Issue

设置页里有“报告问题/创建 Issue”的入口。为了实现默认“无 token / 无隐私数据”构建，这个功能默认是关闭的；只有显式开启后才会启用上报。

- 本地构建（推荐）：先设置环境变量，再运行脚本
  - PowerShell：`$env:ENABLE_ISSUE_REPORTING="1"; $env:CPFEEDBACK_KEY="你的token"`，然后执行 `.\build_windows.ps1`
- 直接 flutter 构建：在构建命令中传入
  - `flutter build windows --release --dart-define=ENABLE_ISSUE_REPORTING=true --dart-define=CPFEEDBACK_KEY=你的token`

注意：`--dart-define` 会在编译期写入产物；请使用权限尽量小的 token，且不要提交到仓库。

## 其他平台支持

- MacOS: [https://github.com/marscey/coriander_player/tree/macos-platform](https://github.com/marscey/coriander_player/tree/macos-platform)
- Linux: [https://github.com/Sh12uku/coriander_player_linux](https://github.com/Sh12uku/coriander_player_linux)

## 软件内快捷键

页面中有文本框且处于输入状态时会自动忽略快捷键操作。如果要使用快捷键，可以点击输入框以外的地方，然后再次使用。

- Esc：返回上一级
- 空格：暂停/播放
- Ctrl + 左方向键：上一曲
- Ctrl + 右方向键：下一曲
- Ctrl + 上方向键：增加音量
- Ctrl + 下方向键：减少音量
- F1：切换沉浸模式

注：使用快捷键调整音量/切歌/播放暂停时，会出现短暂的悬浮提示。

## 提供建议、提交 Bug 或者提 PR

我正处于学习和适应 Github 工作流的阶段，所以目前不设置太多的要求。你只需要注意以下几点：

1. 如果要提交 Bug，请创建一个新的 issue。尽可能说明复现步骤并提供截图。
2. 如果你提交 PR，由于我正在学习相关知识，可能会在处理 PR 时和你沟通如何操作分支之类的问题。

## 本分支特性

- **降调功能**：集成了 BASS_FX 插件，支持在不改变速度的情况下调节音调（Pitch）
- **系统级的音量调节**：新增了系统级的音量调节条，用户可以通过滑动条调整系统全局音量。
- **圆角修改**：修改了播放页带悬浮窗控件的圆角，使其更加圆润。
- **字体粗度调节**：新增了字体粗度调节功能，用户可以在桌面歌词控制区域调整字体粗度。
- **播放页自动隐藏鼠标指针**：鼠标静止一段时间后自动隐藏，移动/点击恢复显示。
- **数据库迁移**：新增了数据库迁移功能，用户可以在设置中迁移到 SQLite 数据库。
- **支持播放 mka**：已加载 BASSWebM.dll，支持播放 WebM 格式的音乐。
- **快捷键悬浮提示**：快捷键操作显示短暂提示；音量菜单内快捷键也会显示气泡。

## 感谢

- [music_api](https://github.com/yhsj0919/music_api.git)：实现歌曲的匹配和歌词的获取
- [Lofty](https://crates.io/crates/lofty)：歌曲标签获取
- [BASS](https://www.un4seen.com/bass.html)：播放乐曲
- [flutter_rust_bridge](https://pub.dev/packages/flutter_rust_bridge)：实现许多 Windows 原生交互
- [Silicon7921](https://github.com/Silicon7921)：绘制了新图标
- [coriander_playeri](https://github.com/Ferry-200/coriander_player)：原版coriander_player项目
- [MiSans](https://hyperos.mi.com/font/zh/)：歌词多字重字体支持
