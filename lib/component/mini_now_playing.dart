import 'package:coriander_player/component/rectangle_progress_indicator.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/component/motion.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/utils.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class MiniNowPlaying extends StatelessWidget {
  const MiniNowPlaying({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(builder: (context, screenType) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            8.0,
            0,
            8.0,
            screenType == ScreenType.small ? 8.0 : 32.0,
          ),
          child: SizedBox(
            height: 64.0,
            width: 600.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: kElevationToShadow[4],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LayoutBuilder(builder: (context, constraints) {
                  return RectangleProgressIndicator(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    child: const _NowPlayingForeground(),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _NowPlayingForeground extends StatefulWidget {
  const _NowPlayingForeground();

  @override
  State<_NowPlayingForeground> createState() => _NowPlayingForegroundState();
}

class _NowPlayingForegroundState extends State<_NowPlayingForeground> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: MotionDuration.fast,
      curve: MotionCurve.standard,
      decoration: BoxDecoration(
        color: _hovered ? scheme.onSecondaryContainer.withOpacity(0.06) : null,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          onHover: (v) => setState(() => _hovered = v),
          onTap: () => context.push(app_paths.NOW_PLAYING_PAGE),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ListenableBuilder(
              listenable: PlayService.instance.playbackService,
              builder: (context, _) {
                final playbackService = PlayService.instance.playbackService;
                final nowPlaying = playbackService.nowPlaying;
                final placeholder = Icon(
                  Symbols.broken_image,
                  size: 48.0,
                  color: scheme.onSecondaryContainer,
                );

                return LayoutBuilder(builder: (context, constraints) {
                  final dense = constraints.maxWidth <= 520;
                  final minimal = constraints.maxWidth <= 440;
                  return Row(
                    children: [
                      nowPlaying != null
                          ? FutureBuilder(
                              future: nowPlaying.cover,
                              builder: (context, snapshot) =>
                                  switch (snapshot.connectionState) {
                                ConnectionState.done => snapshot.data == null
                                    ? placeholder
                                    : ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image(
                                          image: snapshot.data!,
                                          width: 48.0,
                                          height: 48.0,
                                          errorBuilder: (_, __, ___) =>
                                              placeholder,
                                        ),
                                      ),
                                _ => const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              },
                            )
                          : placeholder,
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nowPlaying != null
                                  ? nowPlaying.title
                                  : "Coriander Player",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: scheme.onSecondaryContainer),
                            ),
                            Text(
                              nowPlaying != null
                                  ? "${nowPlaying.artist} - ${nowPlaying.album}"
                                  : "Enjoy music",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: scheme.onSecondaryContainer),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      if (!minimal) _MiniVolumeButton(enabled: !dense),
                      if (!dense) const SizedBox(width: 4.0),
                      if (!dense)
                        IconButton(
                          tooltip: "上一曲",
                          onPressed: playbackService.lastAudio,
                          icon: const Icon(Symbols.skip_previous),
                          color: scheme.onSecondaryContainer,
                        ),
                      if (!dense)
                        IconButton(
                          tooltip: "下一曲",
                          onPressed: playbackService.nextAudio,
                          icon: const Icon(Symbols.skip_next),
                          color: scheme.onSecondaryContainer,
                        ),
                      if (!minimal) _MiniShuffleButton(enabled: !dense),
                      _MiniPlayPauseButton(
                        dense: dense,
                        onSecondaryContainer: scheme.onSecondaryContainer,
                      ),
                      if (!dense) const SizedBox(width: 8.0),
                      if (!dense)
                        _MiniTimeText(color: scheme.onSecondaryContainer),
                    ],
                  );
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayPauseButton extends StatelessWidget {
  const _MiniPlayPauseButton({
    required this.dense,
    required this.onSecondaryContainer,
  });

  final bool dense;
  final Color onSecondaryContainer;

  @override
  Widget build(BuildContext context) {
    final playbackService = PlayService.instance.playbackService;
    return StreamBuilder(
      stream: playbackService.playerStateStream,
      initialData: playbackService.playerState,
      builder: (context, snapshot) {
        late void Function() onPressed;
        if (snapshot.data! == PlayerState.playing) {
          onPressed = playbackService.pause;
        } else if (snapshot.data! == PlayerState.completed) {
          onPressed = playbackService.playAgain;
        } else {
          onPressed = playbackService.start;
        }

        final icon = snapshot.data! == PlayerState.playing
            ? Symbols.pause
            : Symbols.play_arrow;
        if (dense) {
          return IconButton(
            tooltip: snapshot.data! == PlayerState.playing ? "暂停" : "播放",
            onPressed: onPressed,
            icon: Icon(icon),
            color: onSecondaryContainer,
          );
        }

        return IconButton(
          tooltip: snapshot.data! == PlayerState.playing ? "暂停" : "播放",
          onPressed: onPressed,
          icon: Icon(icon),
          color: onSecondaryContainer,
        );
      },
    );
  }
}

class _MiniTimeText extends StatelessWidget {
  const _MiniTimeText({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final playbackService = PlayService.instance.playbackService;
    return StreamBuilder(
      stream: playbackService.positionStream,
      initialData: playbackService.position,
      builder: (context, snapshot) {
        final pos = snapshot.data!;
        final len = playbackService.length;
        final posText = Duration(milliseconds: (pos * 1000).toInt())
            .toStringHMMSS()
            .replaceFirst(RegExp(r'^0:'), '');
        final lenText = Duration(milliseconds: (len * 1000).toInt())
            .toStringHMMSS()
            .replaceFirst(RegExp(r'^0:'), '');
        return Text(
          "$posText / $lenText",
          style: TextStyle(color: color),
        );
      },
    );
  }
}

class _MiniShuffleButton extends StatelessWidget {
  const _MiniShuffleButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final playbackService = PlayService.instance.playbackService;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: playbackService.shuffle,
      builder: (context, value, _) {
        final onPressed =
            enabled ? () => playbackService.useShuffle(!value) : null;
        return IconButton(
          tooltip: value ? "关闭随机" : "开启随机",
          onPressed: onPressed,
          icon: const Icon(Symbols.shuffle),
          color: value ? scheme.primary : scheme.onSecondaryContainer,
        );
      },
    );
  }
}

class _MiniVolumeButton extends StatefulWidget {
  const _MiniVolumeButton({required this.enabled});

  final bool enabled;

  @override
  State<_MiniVolumeButton> createState() => _MiniVolumeButtonState();
}

class _MiniVolumeButtonState extends State<_MiniVolumeButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;
    return MenuAnchor(
      alignmentOffset: const Offset(-8.0, -12.0),
      menuChildren: [
        SizedBox(
          width: 220,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: ListenableBuilder(
              listenable: playbackService,
              builder: (context, _) => Slider(
                min: 0,
                max: 1,
                value: playbackService.volumeDsp.clamp(0.0, 1.0),
                onChanged: widget.enabled ? playbackService.setVolumeDsp : null,
                activeColor: scheme.primary,
                inactiveColor: scheme.outline,
                thumbColor: scheme.primary,
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        return IconButton(
          tooltip: "音量",
          onPressed: widget.enabled
              ? () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
          icon: const Icon(Symbols.volume_up),
          color: scheme.onSecondaryContainer,
        );
      },
    );
  }
}
