import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontVariation;

import 'package:coriander_player/enums.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

FontWeight _discreteFontWeight(int weight) {
  final w = weight.clamp(100, 900);
  return FontWeight.values[((w / 100).round() - 1).clamp(0, 8)];
}

TextStyle _lyricTextStyle({
  required Color color,
  required double fontSize,
  required int weight,
  double? height,
}) {
  final w = weight.clamp(100, 900);
  final shadowColor = color.computeLuminance() > 0.6
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.40);
  return TextStyle(
    color: color,
    fontSize: fontSize,
    fontVariations: [FontVariation('wght', w.toDouble())],
    fontWeight: _discreteFontWeight(w),
    height: height ?? 1.5,
    shadows: [
      Shadow(
        color: shadowColor,
        blurRadius: 3.0,
        offset: const Offset(0, 1),
      ),
    ],
  );
}

const double _mainLinePrimaryScale = 1.00;
const double _mainLineTranslationScale = 0.78;
const double _subLinePrimaryScale = 0.88;
const double _subLineTranslationScale = 0.70;

double _effectiveLyricFontSize(double base, {required bool isMainLine}) {
  return base * (isMainLine ? _mainLinePrimaryScale : _subLinePrimaryScale);
}

double _effectiveTranslationFontSize(double base, {required bool isMainLine}) {
  return base *
      (isMainLine ? _mainLineTranslationScale : _subLineTranslationScale);
}

class LyricViewTile extends StatelessWidget {
  const LyricViewTile(
      {super.key, required this.line, required this.opacity, this.onTap});

  final LyricLine line;
  final double opacity;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final lyricViewController = context.watch<LyricViewController>();
    final isMainLine = opacity == 1.0;

    Widget content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: line is SyncLyricLine
          ? _SyncLineContent(
              syncLine: line as SyncLyricLine,
              isMainLine: isMainLine,
            )
          : _LrcLineContent(
              lrcLine: line as LrcLine,
              isMainLine: isMainLine,
            ),
    );

    if (lyricViewController.enableLyricBlur) {
      content = content.animate(target: isMainLine ? 0 : 1).blurXY(
            end: 2.0,
            duration: 300.ms,
            curve: Curves.easeInOut,
          );
    }

    final alignment = switch (lyricViewController.lyricTextAlign) {
      LyricTextAlign.left => Alignment.centerLeft,
      LyricTextAlign.center => Alignment.center,
      LyricTextAlign.right => Alignment.centerRight,
    };

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: double.infinity,
        child: ClipRect(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              curve: const Cubic(0.2, 0.0, 0.0, 1.0),
              opacity: opacity,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: const Cubic(0.2, 0.0, 0.0, 1.0),
                offset: isMainLine ? Offset.zero : const Offset(0.0, 0.01),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  curve: const Cubic(0.2, 0.0, 0.0, 1.0),
                  alignment: alignment,
                  scale: isMainLine ? 1.1 : 0.9,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncLineContent extends StatelessWidget {
  const _SyncLineContent({required this.syncLine, required this.isMainLine});

  final SyncLyricLine syncLine;
  final bool isMainLine;

  @override
  Widget build(BuildContext context) {
    if (syncLine.words.isEmpty) {
      if (syncLine.length > const Duration(seconds: 5) && isMainLine) {
        return LyricTransitionTile(syncLine: syncLine);
      } else {
        return const SizedBox.shrink();
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    final lyricFontSize = lyricViewController.lyricFontSize;
    final alignment = lyricViewController.lyricTextAlign;
    final showTranslation = lyricViewController.showLyricTranslation;
    final fontWeight = lyricViewController.lyricFontWeight;

    final primarySize =
        _effectiveLyricFontSize(lyricFontSize, isMainLine: isMainLine);
    final translationSize =
        _effectiveTranslationFontSize(lyricFontSize, isMainLine: isMainLine);

    if (!isMainLine) {
      if (syncLine.words.isEmpty) {
        return const SizedBox.shrink();
      }

      final List<Widget> contents = [
        buildPrimaryText(
          syncLine.content,
          scheme,
          alignment,
          primarySize,
          fontWeight,
        ),
      ];
      if (showTranslation && syncLine.translation != null) {
        contents.add(SizedBox(height: isMainLine ? 6.0 : 4.0));
        contents.add(buildSecondaryText(
          syncLine.translation!,
          scheme,
          alignment,
          translationSize,
          fontWeight,
        ));
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: switch (alignment) {
            LyricTextAlign.left => CrossAxisAlignment.start,
            LyricTextAlign.center => CrossAxisAlignment.center,
            LyricTextAlign.right => CrossAxisAlignment.end,
          },
          children: contents,
        ),
      );
    }

    final List<Widget> contents = [
      StreamBuilder(
        stream: PlayService.instance.playbackService.positionStream,
        builder: (context, snapshot) {
          final posInMs = (snapshot.data ?? 0) * 1000;
          return RichText(
            softWrap: true,
            overflow: TextOverflow.clip,
            textAlign: switch (alignment) {
              LyricTextAlign.left => TextAlign.left,
              LyricTextAlign.center => TextAlign.center,
              LyricTextAlign.right => TextAlign.right,
            },
            text: TextSpan(
              children: List.generate(
                syncLine.words.length,
                (i) {
                  final word = syncLine.words[i];
                  final wordLenMs = word.length.inMilliseconds;
                  final wordStartMs = word.start.inMilliseconds.toDouble();
                  final wordEndMs = wordStartMs + wordLenMs;
                  final progress = wordLenMs <= 0
                      ? (posInMs >= wordEndMs ? 1.0 : 0.0)
                      : ((posInMs - wordStartMs) / wordLenMs).clamp(0.0, 1.0);
                  return WidgetSpan(
                    child: Stack(
                      children: [
                        // 底层：未播放状态（暗色）
                        Text(
                          word.content,
                          style: _lyricTextStyle(
                            color: scheme.primary.withOpacity(0.12),
                            fontSize: primarySize,
                            weight: fontWeight,
                            height: 1.5,
                          ),
                        ),
                        // 顶层：已播放状态（亮色），通过 ShaderMask 裁剪
                        if (progress > 0.0)
                          ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: const [
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                  Colors.transparent
                                ],
                                stops: [0, progress, progress + 0.05, 1],
                              ).createShader(bounds);
                            },
                            child: Text(
                              word.content,
                              style: _lyricTextStyle(
                                color: scheme.primary,
                                fontSize: primarySize,
                                weight: fontWeight,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      )
    ];
    if (showTranslation && syncLine.translation != null) {
      contents.add(SizedBox(height: isMainLine ? 8.0 : 4.0));
      contents.add(buildSecondaryText(
        syncLine.translation!,
        scheme,
        alignment,
        translationSize,
        fontWeight,
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: switch (alignment) {
          LyricTextAlign.left => CrossAxisAlignment.start,
          LyricTextAlign.center => CrossAxisAlignment.center,
          LyricTextAlign.right => CrossAxisAlignment.end,
        },
        children: contents,
      ),
    );
  }

  Text buildPrimaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
    int fontWeight,
  ) {
    return Text(
      text,
      softWrap: true,
      overflow: TextOverflow.clip,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: _lyricTextStyle(
        color: scheme.onSecondaryContainer,
        fontSize: fontSize,
        weight: fontWeight,
        height: 1.5,
      ),
    );
  }

  Text buildSecondaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
    int fontWeight,
  ) {
    final translationWeight = (fontWeight - 50).clamp(100, 900);
    return Text(
      text,
      softWrap: true,
      overflow: TextOverflow.clip,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: _lyricTextStyle(
        color: scheme.onSecondaryContainer,
        fontSize: fontSize,
        weight: translationWeight,
        height: 1.10,
      ),
    );
  }
}

class _LrcLineContent extends StatelessWidget {
  const _LrcLineContent({required this.lrcLine, required this.isMainLine});

  final LrcLine lrcLine;
  final bool isMainLine;

  @override
  Widget build(BuildContext context) {
    if (lrcLine.isBlank) {
      if (lrcLine.length > const Duration(seconds: 5) && isMainLine) {
        return LyricTransitionTile(lrcLine: lrcLine);
      } else {
        return const SizedBox.shrink();
      }
    }

    final scheme = Theme.of(context).colorScheme;
    final lyricViewController = context.watch<LyricViewController>();

    final lyricFontSize = lyricViewController.lyricFontSize;
    final alignment = lyricViewController.lyricTextAlign;
    final showTranslation = lyricViewController.showLyricTranslation;
    final fontWeight = lyricViewController.lyricFontWeight;

    final primarySize =
        _effectiveLyricFontSize(lyricFontSize, isMainLine: isMainLine);
    final translationSize =
        _effectiveTranslationFontSize(lyricFontSize, isMainLine: isMainLine);

    final splited = lrcLine.content.split("┃");
    final List<Widget> contents = [
      buildPrimaryText(
        splited.first,
        scheme,
        alignment,
        primarySize,
        fontWeight,
      )
    ];
    if (showTranslation) {
      for (var i = 1; i < splited.length; i++) {
        contents.add(SizedBox(height: i == 1 ? (isMainLine ? 6.0 : 4.0) : 2.0));
        contents.add(buildSecondaryText(
          splited[i],
          scheme,
          alignment,
          translationSize,
          fontWeight,
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: switch (alignment) {
          LyricTextAlign.left => CrossAxisAlignment.start,
          LyricTextAlign.center => CrossAxisAlignment.center,
          LyricTextAlign.right => CrossAxisAlignment.end,
        },
        children: contents,
      ),
    );
  }

  Text buildPrimaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
    int fontWeight,
  ) {
    return Text(
      text,
      softWrap: true,
      overflow: TextOverflow.clip,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: _lyricTextStyle(
        color: scheme.onSecondaryContainer,
        fontSize: fontSize,
        weight: fontWeight,
      ),
    );
  }

  Text buildSecondaryText(
    String text,
    ColorScheme scheme,
    LyricTextAlign align,
    double fontSize,
    int fontWeight,
  ) {
    final translationWeight = (fontWeight - 50).clamp(100, 900);
    return Text(
      text,
      softWrap: true,
      overflow: TextOverflow.clip,
      textAlign: switch (align) {
        LyricTextAlign.left => TextAlign.left,
        LyricTextAlign.center => TextAlign.center,
        LyricTextAlign.right => TextAlign.right,
      },
      style: _lyricTextStyle(
        color: scheme.onSecondaryContainer,
        fontSize: fontSize,
        weight: translationWeight,
      ),
    );
  }
}

/// 歌词间奏表示
/// lrcLine 和 syncLine 必须有且只有一个不为空
class LyricTransitionTile extends StatelessWidget {
  final LrcLine? lrcLine;
  final SyncLyricLine? syncLine;
  const LyricTransitionTile({super.key, this.lrcLine, this.syncLine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40.0,
      width: 80.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
        child: CustomPaint(
          painter: LyricTransitionPainter(
            scheme,
            LyricTransitionTileController(lrcLine, syncLine),
          ),
        ),
      ),
    );
  }
}

class LyricTransitionPainter extends CustomPainter {
  final ColorScheme scheme;
  final LyricTransitionTileController controller;

  final Paint circlePaint1 = Paint();
  final Paint circlePaint2 = Paint();
  final Paint circlePaint3 = Paint();

  final double radius = 6;

  LyricTransitionPainter(this.scheme, this.controller)
      : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    circlePaint1.color = scheme.onSecondaryContainer.withOpacity(
      0.05 + min(controller.progress * 3, 1) * 0.95,
    );
    circlePaint2.color = scheme.onSecondaryContainer.withOpacity(
      0.05 + min(max(controller.progress - 1 / 3, 0) * 3, 1) * 0.95,
    );
    circlePaint3.color = scheme.onSecondaryContainer.withOpacity(
      0.05 + min(max(controller.progress - 2 / 3, 0) * 3, 1) * 0.95,
    );

    final rWithFactor = radius + controller.sizeFactor;
    final c1 = Offset(rWithFactor, 8);
    final c2 = Offset(4 * rWithFactor, 8);
    final c3 = Offset(7 * rWithFactor, 8);

    canvas.drawCircle(c1, rWithFactor, circlePaint1);
    canvas.drawCircle(c2, rWithFactor, circlePaint2);
    canvas.drawCircle(c3, rWithFactor, circlePaint3);
  }

  @override
  bool shouldRepaint(LyricTransitionPainter oldDelegate) => false;

  @override
  bool shouldRebuildSemantics(LyricTransitionPainter oldDelegate) => false;
}

class LyricTransitionTileController extends ChangeNotifier {
  final LrcLine? lrcLine;
  final SyncLyricLine? syncLine;

  final playbackService = PlayService.instance.playbackService;

  double progress = 0;
  late final StreamSubscription positionStreamSub;

  double sizeFactor = 0;
  double k = 1;
  late final Ticker factorTicker;

  LyricTransitionTileController([this.lrcLine, this.syncLine]) {
    positionStreamSub = playbackService.positionStream.listen(_updateProgress);
    factorTicker = Ticker((elapsed) {
      sizeFactor += k * 1 / 180;
      if (sizeFactor > 1) {
        k = -1;
        sizeFactor = 1;
      } else if (sizeFactor < 0) {
        k = 1;
        sizeFactor = 0;
      }
      notifyListeners();
    });
    factorTicker.start();
  }

  void _updateProgress(double position) {
    late int startInMs;
    late int lengthInMs;
    if (lrcLine != null) {
      startInMs = lrcLine!.start.inMilliseconds;
      lengthInMs = lrcLine!.length.inMilliseconds;
    } else {
      startInMs = syncLine!.start.inMilliseconds;
      lengthInMs = syncLine!.length.inMilliseconds;
    }
    final sinceStart = position * 1000 - startInMs;
    progress = max(sinceStart, 0) / lengthInMs;
    notifyListeners();

    if (progress >= 1) {
      dispose();
    }
  }

  @override
  void dispose() {
    positionStreamSub.cancel();
    factorTicker.dispose();
    super.dispose();
  }
}
