part of 'page.dart';

class _NowPlayingPage_Large extends StatelessWidget {
  const _NowPlayingPage_Large();

  @override
  Widget build(BuildContext context) {
    const spacer = SizedBox(width: 8.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              return Row(
                children: [
                  const Expanded(child: Center(child: _NowPlayingInfo())),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: NOW_PLAYING_VIEW_MODE,
                      builder: (context, value, _) => AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: switch (value) {
                          NowPlayingViewMode.withPlaylist =>
                            const CurrentPlaylistView(),
                          _ => Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 820.0),
                                child: const VerticalLyricView(),
                              ),
                            ),
                        },
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12.0),
          const _NowPlayingSlider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DesktopLyricSwitch(),
                      spacer,
                      _NowPlayingPlaybackModeSwitch(),
                      spacer,
                      _NowPlayingVolDspSlider(),
                      spacer,
                      _ExclusiveModeSwitch(),
                    ],
                  ),
                ),
                _NowPlayingMainControls(),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NowPlayingPitchControl(),
                      spacer,
                      SetLyricSourceBtn(),
                      spacer,
                      _NowPlayingLargeViewSwitch(),
                      spacer,
                      _NowPlayingMoreAction(),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 切换视图：lyric / playlist
class _NowPlayingLargeViewSwitch extends StatelessWidget {
  const _NowPlayingLargeViewSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder(
      valueListenable: NOW_PLAYING_VIEW_MODE,
      builder: (context, value, _) => IconButton(
        tooltip: switch (value) {
          NowPlayingViewMode.withPlaylist => "歌词",
          _ => "播放列表",
        },
        onPressed: () {
          if (value == NowPlayingViewMode.onlyMain ||
              value == NowPlayingViewMode.withLyric) {
            NOW_PLAYING_VIEW_MODE.value = NowPlayingViewMode.withPlaylist;
            AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode =
                NowPlayingViewMode.withPlaylist;
          } else {
            NOW_PLAYING_VIEW_MODE.value = NowPlayingViewMode.withLyric;
            AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode =
                NowPlayingViewMode.withLyric;
          }
        },
        icon: switch (value) {
          NowPlayingViewMode.withPlaylist => const _MergedPlaylistIcon(),
          _ => const Icon(Symbols.queue_music),
        },
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _MergedPlaylistIcon extends StatelessWidget {
  const _MergedPlaylistIcon();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: const Size(24, 24),
      painter: _MergedPlaylistIconPainter(
        noteColor: scheme.primary,
        listColor: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _MergedPlaylistIconPainter extends CustomPainter {
  final Color noteColor;
  final Color listColor;

  _MergedPlaylistIconPainter({
    required this.noteColor,
    required this.listColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    // Drawing parameters
    const double barHeight = 3.0;
    const double startX = 11.0;
    const double endX = 22.0;
    const double headRadius = 3.5;

    // Y positions for the three bars (centered vertically approx)
    const double topY = 6.0;
    const double midY = 12.0;
    const double botY = 18.0;

    // 1. Draw List Lines (Right side)
    paint.color = listColor;

    // Top Bar
    canvas.drawRRect(
      RRect.fromLTRBR(
        startX,
        topY - barHeight / 2,
        endX,
        topY + barHeight / 2,
        const Radius.circular(barHeight / 2),
      ),
      paint,
    );

    // Mid Bar
    canvas.drawRRect(
      RRect.fromLTRBR(
        startX,
        midY - barHeight / 2,
        endX,
        midY + barHeight / 2,
        const Radius.circular(barHeight / 2),
      ),
      paint,
    );

    // Bot Bar
    canvas.drawRRect(
      RRect.fromLTRBR(
        startX,
        botY - barHeight / 2,
        endX,
        botY + barHeight / 2,
        const Radius.circular(barHeight / 2),
      ),
      paint,
    );

    // 2. Draw Music Note (Left side)
    paint.color = noteColor;

    // Note Head
    const headCenter = Offset(6.0, 18.0);
    canvas.drawCircle(headCenter, headRadius, paint);

    // Stem
    const double stemWidth = 2.5;
    final stemRect = RRect.fromLTRBR(
      headCenter.dx + headRadius - stemWidth,
      4.0, // Top of stem
      headCenter.dx + headRadius,
      18.0, // Bottom of stem (center of head)
      const Radius.circular(1.0),
    );
    canvas.drawRRect(stemRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
