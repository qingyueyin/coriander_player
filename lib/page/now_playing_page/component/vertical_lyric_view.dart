import 'dart:async';
import 'dart:math';

import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

bool ALWAYS_SHOW_LYRIC_VIEW_CONTROLS = false;

class VerticalLyricView extends StatefulWidget {
  const VerticalLyricView({
    super.key,
    this.showControls = true,
    this.enableSeekOnTap = true,
    this.centerVertically = true,
  });

  final bool showControls;
  final bool enableSeekOnTap;
  final bool centerVertically;

  @override
  State<VerticalLyricView> createState() => _VerticalLyricViewState();
}

class _VerticalLyricViewState extends State<VerticalLyricView> {
  bool isHovering = false;
  final lyricViewController = LyricViewController();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovering = false;
        });
      },
      child: Material(
        type: MaterialType.transparency,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: ChangeNotifierProvider.value(
            value: lyricViewController,
            child: ListenableBuilder(
              listenable: PlayService.instance.lyricService,
              builder: (context, _) => FutureBuilder(
                future: PlayService.instance.lyricService.currLyricFuture,
                builder: (context, snapshot) {
                  final lyricNullable = snapshot.data;
                  final noLyricWidget = Center(
                    child: Text(
                      "无歌词",
                      style: TextStyle(
                        fontSize: 22,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  );

                  return Stack(
                    children: [
                      switch (snapshot.connectionState) {
                        ConnectionState.none => loadingWidget,
                        ConnectionState.waiting => loadingWidget,
                        ConnectionState.active => loadingWidget,
                        ConnectionState.done => lyricNullable == null
                            ? noLyricWidget
                            : _VerticalLyricScrollView(
                                lyric: lyricNullable,
                                enableSeekOnTap: widget.enableSeekOnTap,
                                centerVertically: widget.centerVertically,
                              ),
                      },
                      if (widget.showControls &&
                          (isHovering || ALWAYS_SHOW_LYRIC_VIEW_CONTROLS))
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: LyricViewControls(),
                        )
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalLyricScrollView extends StatefulWidget {
  const _VerticalLyricScrollView({
    required this.lyric,
    required this.enableSeekOnTap,
    required this.centerVertically,
  });

  final Lyric lyric;
  final bool enableSeekOnTap;
  final bool centerVertically;

  @override
  State<_VerticalLyricScrollView> createState() =>
      _VerticalLyricScrollViewState();
}

class _VerticalLyricScrollViewState extends State<_VerticalLyricScrollView>
    with SingleTickerProviderStateMixin {
  final playbackService = PlayService.instance.playbackService;
  final lyricService = PlayService.instance.lyricService;
  late StreamSubscription lyricLineStreamSubscription;
  final scrollController = ScrollController();
  LyricViewController? _lyricViewController;
  Timer? _ensureVisibleTimer;
  Timer? _userScrollHoldTimer;
  Timer? _sizeChangeTimer;
  double _lastHeight = 0.0;
  bool _userScrolling = false;
  static const double _fadeExtent = 0.12;
  int _mainLine = 0;
  int _pendingScrollRetries = 0;

  /// 用来定位到当前歌词
  final currentLyricTileKey = GlobalKey();

  List<double>? _cachedOffsets;
  List<double>? _cachedHeights; // Store heights to center current line
  double _cachedMaxWidth = 0.0;

  @override
  void initState() {
    super.initState();

    _initLyricView();
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_updateNextLyricLine);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      lyricService.findCurrLyricLineAt(playbackService.position);
    });
  }

  void _computeOffsets(double maxWidth) {
    if (maxWidth <= 0) return;
    
    // Get style config
    final controller = context.read<LyricViewController>();
    final baseSize = controller.lyricFontSize;
    final showTrans = controller.showLyricTranslation;
    final weight = controller.lyricFontWeight;
    
    // Constants from LyricViewTile
    const subScale = 0.88;
    const subTransScale = 0.70;
    const mainScale = 1.0;
    const mainTransScale = 0.78;
    
    final subSize = baseSize * subScale;
    final subTransSize = baseSize * subTransScale;
    final mainSize = baseSize * mainScale;
    final mainTransSize = baseSize * mainTransScale;
    
    final subVertPad = (baseSize * 0.35).clamp(10.0, 18.0); // Approximation
    // LrcLine uses 0.32 scale, SyncLine uses 0.35. Let's use avg or Sync's.
    
    final painter = TextPainter(textDirection: TextDirection.ltr);
    
    double measureLine(LyricLine line, bool isMain) {
      final primarySize = isMain ? mainSize : subSize;
      final transSize = isMain ? mainTransSize : subTransSize;
      final contentWidth = maxWidth - 24.0; // Horizontal padding
      
      double h = 0.0;
      
      // Primary text
      String text = "";
      if (line is SyncLyricLine) {
        text = line.content;
      } else if (line is LrcLine) {
        text = line.content.split("┃").first;
      }
      
      painter.text = TextSpan(
        text: text,
        style: TextStyle(fontSize: primarySize, fontWeight: FontWeight.w400, height: 1.5),
      );
      painter.layout(maxWidth: contentWidth);
      h += painter.height;
      
      // Translation
      if (showTrans) {
        String? trans;
        if (line is SyncLyricLine) {
          trans = line.translation;
        } else if (line is LrcLine) {
          final parts = line.content.split("┃");
          if (parts.length > 1) trans = parts.skip(1).join("\n");
        }
        
        if (trans != null && trans.isNotEmpty) {
          h += (isMain ? 6.0 : 4.0); // Spacing
          painter.text = TextSpan(
            text: trans,
            style: TextStyle(fontSize: transSize, fontWeight: FontWeight.w400, height: 1.1),
          );
          painter.layout(maxWidth: contentWidth);
          h += painter.height;
        }
      }
      
      // Vertical padding (top + bottom)
      h += subVertPad * 2;
      return h;
    }

    final offsets = <double>[];
    final heights = <double>[];
    double currentOffset = 0.0;
    
    for (int i = 0; i < widget.lyric.lines.length; i++) {
      offsets.add(currentOffset);
      // We assume all previous lines are NOT main lines (sub style)
      // The current line will be rendered as Main, but for offset calculation of *next* lines,
      // this line (when it becomes previous) will be Sub.
      // So cachedOffsets[i] represents the top position of line i.
      
      // We also need the height of line i IF it is Main, to center it.
      final hAsMain = measureLine(widget.lyric.lines[i], true);
      heights.add(hAsMain);
      
      // Advance offset by its Sub height (for next items)
      final hAsSub = measureLine(widget.lyric.lines[i], false);
      currentOffset += hAsSub;
    }
    
    _cachedOffsets = offsets;
    _cachedHeights = heights;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<LyricViewController>();
    if (_lyricViewController == controller) return;

    _lyricViewController?.removeListener(_scheduleEnsureCurrentVisible);
    _lyricViewController = controller;
    _lyricViewController?.addListener(_scheduleEnsureCurrentVisible);
    
    // Clear cache to recompute on next layout (font size might change)
    _cachedMaxWidth = 0.0;
    _cachedOffsets = null;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(const Duration(milliseconds: 100));
    });
  }

  void _scheduleEnsureCurrentVisible() {
    _cachedMaxWidth = 0.0; // Force recompute
    _ensureVisibleTimer?.cancel();
    _ensureVisibleTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      if (mounted) setState(() {}); // Trigger rebuild to recompute
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    });
  }

  void _animateTo(double targetOffset, {Duration? duration}) {
    if (!scrollController.hasClients) return;
    final minExtent = scrollController.position.minScrollExtent;
    final maxExtent = scrollController.position.maxScrollExtent;
    final to = targetOffset.clamp(minExtent, maxExtent);
    
    if (duration != null && duration.inMilliseconds <= 16) {
      scrollController.jumpTo(to);
      return;
    }
    
    final from = scrollController.offset;
    final dist = (to - from).abs();
    if (dist < 0.5) return;

    final computed = duration ??
        Duration(
          milliseconds: (280 + dist * 0.22).round().clamp(320, 650),
        );
    scrollController.animateTo(to, duration: computed, curve: Curves.easeOutQuart);
  }

  void _scrollToCurrent([Duration? duration]) {
    if (_userScrolling) return;
    if (!scrollController.hasClients) {
      if (_pendingScrollRetries < 4) {
        _pendingScrollRetries++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToCurrent(duration);
        });
      }
      return;
    }
    _pendingScrollRetries = 0;

    // Use cached offsets if available
    if (_cachedOffsets != null && _cachedHeights != null && 
        _mainLine < _cachedOffsets!.length) {
      
      final viewport = scrollController.position.viewportDimension;
      final spacer = widget.centerVertically ? viewport / 2.0 : 0.0;
      final alignment = widget.centerVertically ? 0.5 : 0.25;
      
      final lineTop = _cachedOffsets![_mainLine];
      final lineHeight = _cachedHeights![_mainLine];
      
      // Target position: 
      // We want the center of the line to be at `viewport * alignment`.
      // The content starts at `spacer`.
      // lineTop is relative to the first item (which starts at spacer).
      // So absolute lineTop = spacer + lineTop.
      // absolute lineCenter = absolute lineTop + lineHeight / 2.
      // scrollOffset = absolute lineCenter - (viewport * alignment).
      
      final targetScrollOffset = (spacer + lineTop + lineHeight / 2) - (viewport * alignment);
      
      _animateTo(targetScrollOffset, duration: duration);
      return;
    }

    // Fallback to original logic (should rarely happen if layout built)
    final targetContext = currentLyricTileKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
       // ... (Simplified fallback: just wait)
       return;
    }
    
    final targetObject = targetContext.findRenderObject();
    if (targetObject is! RenderBox) return;
    final viewport = RenderAbstractViewport.of(targetObject);
    if (viewport == null) return;

    final alignment = widget.centerVertically ? 0.5 : 0.25;
    final revealed = viewport.getOffsetToReveal(targetObject, alignment);
    _animateTo(revealed.offset, duration: duration);
  }

  void _initLyricView() {
    final next = widget.lyric.lines.indexWhere(
      (element) =>
          element.start.inMilliseconds / 1000 > playbackService.position,
    );
    final nextLyricLine = next == -1 ? widget.lyric.lines.length : next;
    _mainLine = max(nextLyricLine - 1, 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent(const Duration(milliseconds: 320));
    });
  }

  void _seekToLyricLine(int i) {
    playbackService.seek(widget.lyric.lines[i].start.inMilliseconds / 1000);
    setState(() {
      _mainLine = i;
    });
  }

  void _updateNextLyricLine(int lyricLine) {
    setState(() {
      _mainLine = lyricLine;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth != _cachedMaxWidth) {
        _cachedMaxWidth = constraints.maxWidth;
        // Recompute in next frame to avoid blocking build? 
        // Or compute now. It's better to compute now to have correct offsets immediately.
        _computeOffsets(constraints.maxWidth);
      }
      
      final spacerHeight = constraints.maxHeight / 2.0;
      return RepaintBoundary(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, _fadeExtent, 1.0 - _fadeExtent, 1.0],
            ).createShader(bounds);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                _userScrollHoldTimer?.cancel();
                _userScrolling = true;
                _userScrollHoldTimer = Timer(const Duration(seconds: 2), () {
                  if (!mounted) return;
                  _userScrolling = false;
                  _scrollToCurrent();
                });
              }
              return false;
            },
            child: ListView.builder(
              key: ValueKey(widget.lyric.hashCode),
              controller: scrollController,
              padding: EdgeInsets.symmetric(
                vertical: widget.centerVertically ? spacerHeight : 0,
              ),
              itemCount: widget.lyric.lines.length,
              itemBuilder: (context, i) {
                final dist = (i - _mainLine).abs();
                final opacity = dist == 0
                    ? 1.0
                    : pow(0.72, dist).toDouble().clamp(0.16, 0.78);
                return LyricViewTile(
                  key: dist == 0 ? currentLyricTileKey : null,
                  line: widget.lyric.lines[i],
                  opacity: opacity,
                  distance: dist,
                  onTap:
                      widget.enableSeekOnTap ? () => _seekToLyricLine(i) : null,
                );
              },
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    _ensureVisibleTimer?.cancel();
    _userScrollHoldTimer?.cancel();
    _sizeChangeTimer?.cancel();
    _lyricViewController?.removeListener(_scheduleEnsureCurrentVisible);
    lyricLineStreamSubscription.cancel();
    scrollController.dispose();
  }
}
