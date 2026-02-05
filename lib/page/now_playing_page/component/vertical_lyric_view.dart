import 'dart:async';
import 'dart:math';

import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_controls.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_view_tile.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
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
  bool _userScrolling = false;
  late final AnimationController _scrollAnimation;
  static const _scrollCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const double _fadeExtent = 0.12;
  static const double _scrollMsPerPixel = 0.55;
  static const int _scrollMinMs = 220;
  static const int _scrollMaxMs = 420;
  int _mainLine = 0;
  double _estimatedItemExtent = 56.0;
  int _pendingScrollRetries = 0;

  /// 用来定位到当前歌词
  final currentLyricTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _scrollAnimation = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!scrollController.hasClients) return;
        final minExtent = scrollController.position.minScrollExtent;
        final maxExtent = scrollController.position.maxScrollExtent;
        final target = _scrollAnimation.value.clamp(minExtent, maxExtent);
        if ((scrollController.offset - target).abs() < 0.5) return;
        scrollController.jumpTo(target);
      });

    _initLyricView();
    lyricLineStreamSubscription =
        lyricService.lyricLineStream.listen(_updateNextLyricLine);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = context.read<LyricViewController>();
    if (_lyricViewController == controller) return;

    _lyricViewController?.removeListener(_scheduleEnsureCurrentVisible);
    _lyricViewController = controller;
    _lyricViewController?.addListener(_scheduleEnsureCurrentVisible);
  }

  void _scheduleEnsureCurrentVisible() {
    _ensureVisibleTimer?.cancel();
    _ensureVisibleTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _scrollToCurrent();
    });
  }

  void _springTo(double targetOffset) {
    if (!scrollController.hasClients) return;
    final minExtent = scrollController.position.minScrollExtent;
    final maxExtent = scrollController.position.maxScrollExtent;
    final from = scrollController.offset;
    final to = targetOffset.clamp(minExtent, maxExtent);
    final dist = (to - from).abs();
    if (dist < 0.5) return;

    _scrollAnimation.stop();
    _scrollAnimation.value = from;

    final ms = (dist * _scrollMsPerPixel).round().clamp(_scrollMinMs, _scrollMaxMs);
    final t = (ms / 1000.0).clamp(0.18, 0.42);
    final stiffness = 520.0;
    final damping = 2 *
        sqrt(stiffness) *
        (0.92 + 0.08 * (1 - ((t - 0.18) / 0.24).clamp(0.0, 1.0)));

    final sim = SpringSimulation(
      SpringDescription(mass: 1.0, stiffness: stiffness, damping: damping),
      from,
      to,
      0.0,
    );
    _scrollAnimation.animateWith(sim);
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

    final targetContext = currentLyricTileKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      final alignment = widget.centerVertically ? 0.5 : 0.25;
      final viewport = scrollController.position.viewportDimension;
      final estimated = (_estimatedItemExtent * _mainLine) - viewport * alignment;
      _springTo(estimated);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCurrent(const Duration(milliseconds: 220));
      });
      return;
    }

    final targetObject = targetContext.findRenderObject();
    if (targetObject is! RenderBox) return;
    final viewport = RenderAbstractViewport.of(targetObject);
    if (viewport == null) return;

    final alignment = widget.centerVertically ? 0.5 : 0.25;
    final revealed = viewport.getOffsetToReveal(targetObject, alignment);
    final targetOffset = revealed.offset.clamp(
      scrollController.position.minScrollExtent,
      scrollController.position.maxScrollExtent,
    );

    final h = targetObject.size.height;
    if (h.isFinite && h > 0) {
      _estimatedItemExtent = _estimatedItemExtent * 0.8 + h * 0.2;
    }

    _springTo(targetOffset);
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
          child: SingleChildScrollView(
            key: ValueKey(widget.lyric.hashCode),
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              vertical: widget.centerVertically ? spacerHeight : 0,
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _userScrollHoldTimer?.cancel();
                  _userScrolling = true;
                  _scrollAnimation.stop();
                  _userScrollHoldTimer = Timer(const Duration(seconds: 2), () {
                    if (!mounted) return;
                    _userScrolling = false;
                    _scrollToCurrent();
                  });
                }
                return false;
              },
              child: Column(
                children: List.generate(
                  widget.lyric.lines.length,
                  (i) {
                    final dist = (i - _mainLine).abs();
                    final opacity = dist == 0
                        ? 1.0
                        : (1.0 - dist * 0.28).clamp(0.18, 0.80);
                    return LyricViewTile(
                      key: dist == 0 ? currentLyricTileKey : null,
                      line: widget.lyric.lines[i],
                      opacity: opacity,
                      distance: dist,
                      onTap: widget.enableSeekOnTap ? () => _seekToLyricLine(i) : null,
                    );
                  },
                ),
              ),
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
    _lyricViewController?.removeListener(_scheduleEnsureCurrentVisible);
    lyricLineStreamSubscription.cancel();
    _scrollAnimation.dispose();
    scrollController.dispose();
  }
}
