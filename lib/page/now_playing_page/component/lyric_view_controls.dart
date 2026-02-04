import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/enums.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

class LyricViewController extends ChangeNotifier {
  final nowPlayingPagePref = AppPreference.instance.nowPlayingPagePref;
  late LyricTextAlign lyricTextAlign = nowPlayingPagePref.lyricTextAlign;
  late double lyricFontSize = nowPlayingPagePref.lyricFontSize;
  late double translationFontSize = nowPlayingPagePref.translationFontSize;
  late bool showLyricTranslation = nowPlayingPagePref.showLyricTranslation;
  late int lyricFontWeight = nowPlayingPagePref.lyricFontWeight;
  late bool enableLyricBlur = nowPlayingPagePref.enableLyricBlur;

  /// 在左对齐、居中、右对齐之间循环切换
  void switchLyricTextAlign() {
    lyricTextAlign = switch (lyricTextAlign) {
      LyricTextAlign.left => LyricTextAlign.center,
      LyricTextAlign.center => LyricTextAlign.right,
      LyricTextAlign.right => LyricTextAlign.left,
    };

    nowPlayingPagePref.lyricTextAlign = lyricTextAlign;
    notifyListeners();
  }

  void increaseFontSize() {
    if (lyricFontSize >= 48) return;
    lyricFontSize += 2;
    translationFontSize = lyricFontSize - 4; // Sync translation size
    nowPlayingPagePref.lyricFontSize = lyricFontSize;
    nowPlayingPagePref.translationFontSize = translationFontSize;
    AppPreference.instance.save();
    notifyListeners();
  }

  void decreaseFontSize() {
    if (lyricFontSize <= 16) return;
    lyricFontSize -= 2;
    translationFontSize = lyricFontSize - 4; // Sync translation size
    nowPlayingPagePref.lyricFontSize = lyricFontSize;
    nowPlayingPagePref.translationFontSize = translationFontSize;
    AppPreference.instance.save();
    notifyListeners();
  }

  void toggleLyricTranslation() {
    showLyricTranslation = !showLyricTranslation;
    nowPlayingPagePref.showLyricTranslation = showLyricTranslation;
    notifyListeners();
  }

  void toggleLyricBlur() {
    enableLyricBlur = !enableLyricBlur;
    nowPlayingPagePref.enableLyricBlur = enableLyricBlur;
    AppPreference.instance.save();
    notifyListeners();
  }

  void setFontWeight(int weight) {
    if (weight < 100) weight = 100;
    if (weight > 900) weight = 900;

    lyricFontWeight = weight;
    nowPlayingPagePref.lyricFontWeight = lyricFontWeight;
    notifyListeners();
  }

  void increaseFontWeight({bool smallStep = false}) {
    int step = smallStep ? 10 : 100;
    int newWeight = lyricFontWeight + step;
    setFontWeight(newWeight);
  }

  void decreaseFontWeight({bool smallStep = false}) {
    int step = smallStep ? 10 : 100;
    int newWeight = lyricFontWeight - step;
    setFontWeight(newWeight);
  }
}

class LyricViewControls extends StatelessWidget {
  const LyricViewControls({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder2(
      builder: (context, screenType) {
        if (screenType == ScreenType.small) {
          // 竖屏/小屏模式：一列，6个控件
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _IncreaseFontSizeBtn(),
                const SizedBox(height: 8.0),
                const _DecreaseFontSizeBtn(),
                const SizedBox(height: 8.0),
                const _LyricTranslationSwitchBtn(),
                const SizedBox(height: 8.0),
                const _LyricBlurSwitchBtn(),
                const SizedBox(height: 8.0),
                const _LyricAlignSwitchBtn(),
                const SizedBox(height: 8.0),
                const _IncreaseFontWeightBtn(),
                const SizedBox(height: 8.0),
                const _DecreaseFontWeightBtn(),
              ],
            ),
          );
        } else {
          // 横屏/大屏模式：一行两个
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LyricTranslationSwitchBtn(),
                    SizedBox(width: 8.0),
                    _LyricBlurSwitchBtn(),
                    SizedBox(width: 8.0),
                    _LyricAlignSwitchBtn(),
                  ],
                ),
                const SizedBox(height: 8.0),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IncreaseFontSizeBtn(),
                    SizedBox(width: 8.0),
                    _DecreaseFontSizeBtn(),
                  ],
                ),
                const SizedBox(height: 8.0),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IncreaseFontWeightBtn(),
                    SizedBox(width: 8.0),
                    _DecreaseFontWeightBtn(),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class _LyricAlignSwitchBtn extends StatelessWidget {
  const _LyricAlignSwitchBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      onPressed: lyricViewController.switchLyricTextAlign,
      tooltip: "切换歌词对齐方向",
      color: scheme.onSecondaryContainer,
      icon: Icon(switch (lyricViewController.lyricTextAlign) {
        LyricTextAlign.left => Symbols.format_align_left,
        LyricTextAlign.center => Symbols.format_align_center,
        LyricTextAlign.right => Symbols.format_align_right,
      }),
    );
  }
}

class _IncreaseFontSizeBtn extends StatelessWidget {
  const _IncreaseFontSizeBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      onPressed: lyricViewController.increaseFontSize,
      tooltip: "增大歌词字体",
      color: scheme.onSecondaryContainer,
      icon: const Icon(Symbols.text_increase),
    );
  }
}

class _DecreaseFontSizeBtn extends StatelessWidget {
  const _DecreaseFontSizeBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      onPressed: lyricViewController.decreaseFontSize,
      tooltip: "减小歌词字体",
      color: scheme.onSecondaryContainer,
      icon: const Icon(Symbols.text_decrease),
    );
  }
}

class _LyricTranslationSwitchBtn extends StatelessWidget {
  const _LyricTranslationSwitchBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();
    final enabled = lyricViewController.showLyricTranslation;

    return IconButton(
      onPressed: lyricViewController.toggleLyricTranslation,
      tooltip: enabled ? "歌词翻译：显示" : "歌词翻译：隐藏",
      color: scheme.onSecondaryContainer,
      icon: Icon(
        Symbols.translate,
        fill: enabled ? 1 : 0,
      ),
    );
  }
}

class _LyricBlurSwitchBtn extends StatelessWidget {
  const _LyricBlurSwitchBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();
    final enabled = lyricViewController.enableLyricBlur;

    return IconButton(
      onPressed: lyricViewController.toggleLyricBlur,
      tooltip: enabled ? "歌词模糊：开启" : "歌词模糊：关闭",
      color: scheme.onSecondaryContainer,
      icon: Icon(
        Symbols.blur_on,
        fill: enabled ? 1 : 0,
      ),
    );
  }
}

class _IncreaseFontWeightBtn extends StatelessWidget {
  const _IncreaseFontWeightBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      onPressed: () => lyricViewController.increaseFontWeight(),
      tooltip: "增加字体粗细 (${lyricViewController.lyricFontWeight})",
      icon: Text(
        "B+",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.onSecondaryContainer,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _DecreaseFontWeightBtn extends StatelessWidget {
  const _DecreaseFontWeightBtn();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    return IconButton(
      onPressed: () => lyricViewController.decreaseFontWeight(),
      tooltip: "减小字体粗细 (${lyricViewController.lyricFontWeight})",
      icon: Text(
        "B-",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: scheme.onSecondaryContainer,
          fontSize: 16,
        ),
      ),
    );
  }
}
