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
          NowPlayingViewMode.withPlaylist => const _SwappedLayerIcon(),
          _ => const Icon(Symbols.queue_music),
        },
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _SwappedLayerIcon extends StatelessWidget {
  const _SwappedLayerIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Symbols.music_note, size: 20),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Icon(Symbols.format_list_bulleted, size: 18),
          ),
        ],
      ),
    );
  }
}
