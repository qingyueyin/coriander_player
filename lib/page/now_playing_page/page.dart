// ignore_for_file: camel_case_types

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/title_bar.dart';
import 'package:coriander_player/enums.dart';
import 'package:coriander_player/utils.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/page/now_playing_page/component/current_playlist_view.dart';
import 'package:coriander_player/page/now_playing_page/component/filled_icon_button_style.dart';
import 'package:coriander_player/page/now_playing_page/component/lyric_source_view.dart';
import 'package:coriander_player/page/now_playing_page/component/pitch_control.dart';
import 'package:coriander_player/page/now_playing_page/component/vertical_lyric_view.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/play_service/playback_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

part 'small_page.dart';
part 'large_page.dart';

final NOW_PLAYING_VIEW_MODE = ValueNotifier(
  AppPreference.instance.nowPlayingPagePref.nowPlayingViewMode,
);

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final playbackService = PlayService.instance.playbackService;
  ImageProvider<Object>? nowPlayingCover;

  void updateCover() {
    playbackService.nowPlaying?.cover.then((cover) {
      if (mounted) {
        setState(() {
          nowPlayingCover = cover;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService.addListener(updateCover);
    updateCover();
  }

  @override
  void dispose() {
    playbackService.removeListener(updateCover);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56.0),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              NavBackBtn(),
              Expanded(child: DragToMoveArea(child: SizedBox.expand())),
              WindowControlls(),
            ],
          ),
        ),
      ),
      backgroundColor: scheme.secondaryContainer,
      body: Stack(
        fit: StackFit.expand,
        alignment: AlignmentDirectional.center,
        children: [
          if (nowPlayingCover != null) ...[
            Image(
              image: nowPlayingCover!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            switch (brightness) {
              Brightness.dark => const ColoredBox(color: Colors.black45),
              Brightness.light => const ColoredBox(color: Colors.white54),
            },
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 250, sigmaY: 250),
              child: const ColoredBox(color: Colors.transparent),
            ),
          ],
          ChangeNotifierProvider.value(
            value: PlayService.instance.playbackService,
            builder: (context, _) {
              return ResponsiveBuilder2(builder: (context, screenType) {
                switch (screenType) {
                  case ScreenType.small:
                    return const _NowPlayingPage_Small();
                  case ScreenType.medium:
                  case ScreenType.large:
                    return const _NowPlayingPage_Large();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

class _ExclusiveModeSwitch extends StatelessWidget {
  const _ExclusiveModeSwitch();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: PlayService.instance.playbackService.wasapiExclusive,
      builder: (context, exclusive, _) => IconButton(
        tooltip: "独占模式；现在：${exclusive ? "启用" : "禁用"}",
        onPressed: () {
          PlayService.instance.playbackService.useExclusiveMode(!exclusive);
        },
        icon: Center(
          child: Text(
            exclusive ? "Excl" : "Shrd",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingMoreAction extends StatelessWidget {
  const _NowPlayingMoreAction();

  @override
  Widget build(BuildContext context) {
    final playbackService = context.watch<PlaybackService>();
    final nowPlaying = playbackService.nowPlaying;
    final scheme = Theme.of(context).colorScheme;
    final menuStyle = MenuStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
    final menuItemStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (nowPlaying == null) {
      return IconButton(
        tooltip: "更多",
        onPressed: null,
        icon: const Icon(Symbols.more_vert),
        color: scheme.onSecondaryContainer,
      );
    }

    return MenuTheme(
      data: MenuThemeData(style: menuStyle),
      child: MenuAnchor(
        style: menuStyle,
        menuChildren: [
          SubmenuButton(
            style: menuItemStyle,
            menuChildren: List.generate(
              nowPlaying.splitedArtists.length,
              (i) => MenuItemButton(
                style: menuItemStyle,
                onPressed: () {
                  final Artist artist = AudioLibrary
                      .instance.artistCollection[nowPlaying.splitedArtists[i]]!;
                  context.pushReplacement(
                    app_paths.ARTIST_DETAIL_PAGE,
                    extra: artist,
                  );
                },
                leadingIcon: const Icon(Symbols.people),
                child: Text(nowPlaying.splitedArtists[i]),
              ),
            ),
            child: const Text("艺术家"),
          ),
          MenuItemButton(
            style: menuItemStyle,
            onPressed: () {
              final Album album =
                  AudioLibrary.instance.albumCollection[nowPlaying.album]!;
              context.pushReplacement(app_paths.ALBUM_DETAIL_PAGE,
                  extra: album);
            },
            leadingIcon: const Icon(Symbols.album),
            child: Text(nowPlaying.album),
          ),
          MenuItemButton(
            style: menuItemStyle,
            onPressed: () {
              context.pushReplacement(app_paths.AUDIO_DETAIL_PAGE,
                  extra: nowPlaying);
            },
            leadingIcon: const Icon(Symbols.info),
            child: const Text("详细信息"),
          ),
          SubmenuButton(
            style: menuItemStyle,
            menuChildren: List.generate(
              PLAYLISTS.length,
              (i) => MenuItemButton(
                style: menuItemStyle,
                onPressed: () {
                  final added = PLAYLISTS[i].audios.containsKey(nowPlaying.path);
                  if (added) {
                    showTextOnSnackBar("歌曲“${nowPlaying.title}”已存在");
                    return;
                  }
                  PLAYLISTS[i].audios[nowPlaying.path] = nowPlaying;
                  showTextOnSnackBar(
                    "成功将“${nowPlaying.title}”添加到歌单“${PLAYLISTS[i].name}”",
                  );
                },
                leadingIcon: const Icon(Symbols.queue_music),
                child: Text(PLAYLISTS[i].name),
              ),
            ),
            child: const Text("添加到歌单"),
          ),
        ],
        builder: (context, controller, _) => IconButton(
          tooltip: "更多",
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: const Icon(Symbols.more_vert),
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _DesktopLyricSwitch extends StatelessWidget {
  const _DesktopLyricSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: PlayService.instance.desktopLyricService,
      builder: (context, _) {
        final desktopLyricService = PlayService.instance.desktopLyricService;
        return FutureBuilder(
          future: desktopLyricService.desktopLyric,
          builder: (context, snapshot) => IconButton(
            tooltip: "桌面歌词；现在：${snapshot.data == null ? "禁用" : "启用"}",
            onPressed: snapshot.data == null
                ? desktopLyricService.startDesktopLyric
                : desktopLyricService.isLocked
                    ? desktopLyricService.sendUnlockMessage
                    : desktopLyricService.killDesktopLyric,
            icon: snapshot.connectionState == ConnectionState.done
                ? Icon(
                    desktopLyricService.isLocked ? Symbols.lock : Symbols.toast,
                    fill: snapshot.data == null ? 0 : 1,
                  )
                : const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  ),
            color: scheme.onSecondaryContainer,
          ),
        );
      },
    );
  }
}

class _NowPlayingVolDspSlider extends StatefulWidget {
  const _NowPlayingVolDspSlider();

  @override
  State<_NowPlayingVolDspSlider> createState() =>
      _NowPlayingVolDspSliderState();
}

class _NowPlayingVolDspSliderState extends State<_NowPlayingVolDspSlider> {
  final playbackService = PlayService.instance.playbackService;
  final dragVolDsp = ValueNotifier(
    AppPreference.instance.playbackPref.volumeDsp,
  );
  final dragSystemVol = ValueNotifier(0.0);

  bool isDragging = false;
  bool isSystemDragging = false;
  Timer? _systemVolPollTimer;
  bool _systemVolPollBusy = false;
  Timer? _systemVolBoostTimer;
  int _systemVolReadFailures = 0;
  late final void Function(double) _systemVolListener;
  Timer? _indicatorTimer;
  Timer? _systemIndicatorTimer;
  bool _showCustomIndicator = false;
  bool _showSystemCustomIndicator = false;
  bool _isHovering = false;
  bool _isSystemHovering = false;

  Future<double?> _readSystemVol({required Duration timeout}) async {
    try {
      return await FlutterVolumeController.getVolume().timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  void _rebindSystemVolListener() {
    FlutterVolumeController.removeListener();
    FlutterVolumeController.addListener(_systemVolListener);
  }

  @override
  void initState() {
    super.initState();
    _systemVolListener = (v) {
      if (mounted && !isSystemDragging) {
        dragSystemVol.value = v;
      }
    };
    FlutterVolumeController.addListener(_systemVolListener);
    _readSystemVol(timeout: const Duration(milliseconds: 600)).then((v) {
      if (!mounted) return;
      dragSystemVol.value = v ?? 0.5;
    });

    if (Platform.isWindows) {
      _systemVolPollTimer =
          Timer.periodic(const Duration(milliseconds: 250), (_) async {
        if (!mounted || isSystemDragging || _systemVolPollBusy) return;
        _systemVolPollBusy = true;
        try {
          final v = await _readSystemVol(timeout: const Duration(seconds: 1));
          if (!mounted || isSystemDragging) return;
          if (v == null) {
            _systemVolReadFailures += 1;
            if (_systemVolReadFailures >= 3) {
              _systemVolReadFailures = 0;
              _rebindSystemVolListener();
            }
            return;
          }
          _systemVolReadFailures = 0;
          final curr = dragSystemVol.value;
          if ((v - curr).abs() > 0.005) {
            dragSystemVol.value = v;
          }
        } finally {
          _systemVolPollBusy = false;
        }
      });
    }
  }

  void _triggerIndicator() {
    setState(() => _showCustomIndicator = true);
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showCustomIndicator = false);
      }
    });
  }

  void _triggerSystemIndicator() {
    setState(() => _showSystemCustomIndicator = true);
    _systemIndicatorTimer?.cancel();
    _systemIndicatorTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showSystemCustomIndicator = false);
      }
    });
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    _systemVolPollTimer?.cancel();
    _systemVolBoostTimer?.cancel();
    _indicatorTimer?.cancel();
    _systemIndicatorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MenuAnchor(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      onOpen: () {
        int ticks = 0;
        _systemVolBoostTimer?.cancel();
        _systemVolBoostTimer =
            Timer.periodic(const Duration(milliseconds: 120), (_) async {
          if (!mounted || isSystemDragging) return;
          if (ticks++ > 25) {
            _systemVolBoostTimer?.cancel();
            return;
          }
          final v =
              await _readSystemVol(timeout: const Duration(milliseconds: 500));
          if (v != null && (v - dragSystemVol.value).abs() > 0.003) {
            dragSystemVol.value = v;
          }
        });
      },
      onClose: () {
        _systemVolBoostTimer?.cancel();
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // System Volume Slider
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                  child: Text(
                    "系统音量",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
                SliderTheme(
                  data: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: dragSystemVol,
                    builder: (context, systemVolValue, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const double padding = 24.0;
                          final double trackWidth =
                              constraints.maxWidth - (padding * 2);
                          const double min = 0.0;
                          const double max = 1.0;
                          final double percent =
                              (systemVolValue - min) / (max - min);
                          final double leftOffset =
                              padding + (trackWidth * percent);

                          return MouseRegion(
                            onEnter: (_) =>
                                setState(() => _isSystemHovering = true),
                            onExit: (_) =>
                                setState(() => _isSystemHovering = false),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                Slider(
                                  thumbColor: scheme.secondary,
                                  activeColor: scheme.secondary,
                                  inactiveColor: scheme.outline,
                                  min: min,
                                  max: max,
                                  value: systemVolValue,
                                  onChangeStart: (value) {
                                    isSystemDragging = true;
                                    dragSystemVol.value = value;
                                    FlutterVolumeController.setVolume(value);
                                    _triggerSystemIndicator();
                                  },
                                  onChanged: (value) {
                                    dragSystemVol.value = value;
                                    FlutterVolumeController.setVolume(value);
                                    if (isSystemDragging)
                                      _triggerSystemIndicator();
                                  },
                                  onChangeEnd: (value) {
                                    isSystemDragging = false;
                                    dragSystemVol.value = value;
                                    FlutterVolumeController.setVolume(value);
                                  },
                                ),
                                if (_showSystemCustomIndicator ||
                                    _isSystemHovering)
                                  Positioned(
                                    left: leftOffset - 24.0,
                                    top: -40,
                                    child: IgnorePointer(
                                      child: _CustomValueIndicator(
                                        value: systemVolValue * 100,
                                        suffix: "%",
                                        color: scheme.secondary,
                                        textColor: scheme.onSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8.0),
                const Divider(height: 20),
                const SizedBox(height: 4.0),
                // App Volume Slider
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
                  child: Text(
                    "应用音量",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                    ),
                  ),
                ),
                SliderTheme(
                  data: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: dragVolDsp,
                    builder: (context, dragVolDspValue, _) {
                      final currentValue = isDragging
                          ? dragVolDspValue
                          : playbackService.volumeDsp;

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          const double padding = 24.0;
                          final double trackWidth =
                              constraints.maxWidth - (padding * 2);
                          const double min = 0.0;
                          const double max = 1.0;
                          final double percent =
                              (currentValue - min) / (max - min);
                          final double leftOffset =
                              padding + (trackWidth * percent);

                          return MouseRegion(
                            onEnter: (_) => setState(() => _isHovering = true),
                            onExit: (_) => setState(() => _isHovering = false),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.centerLeft,
                              children: [
                                Slider(
                                  thumbColor: scheme.primary,
                                  activeColor: scheme.primary,
                                  inactiveColor: scheme.outline,
                                  min: min,
                                  max: max,
                                  value: currentValue,
                                  onChangeStart: (value) {
                                    isDragging = true;
                                    dragVolDsp.value = value;
                                    playbackService.setVolumeDsp(value);
                                    _triggerIndicator();
                                  },
                                  onChanged: (value) {
                                    dragVolDsp.value = value;
                                    playbackService.setVolumeDsp(value);
                                    // Also trigger indicator on drag
                                    if (isDragging) _triggerIndicator();
                                  },
                                  onChangeEnd: (value) {
                                    isDragging = false;
                                    dragVolDsp.value = value;
                                    playbackService.setVolumeDsp(value);
                                  },
                                ),
                                if (_showCustomIndicator || _isHovering)
                                  Positioned(
                                    left: leftOffset -
                                        24.0, // Center the bubble (width 48)
                                    top: -40,
                                    child: IgnorePointer(
                                      child: _CustomValueIndicator(
                                        value: currentValue * 100,
                                        suffix: "%",
                                        color: scheme.primary,
                                        textColor: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: "音量",
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
        icon: const Icon(Symbols.volume_up),
        color: scheme.onSecondaryContainer,
      ),
    );
  }
}

class _CustomValueIndicator extends StatelessWidget {
  final double value;
  final String suffix;
  final Color color;
  final Color textColor;

  const _CustomValueIndicator({
    required this.value,
    this.suffix = "",
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            "${value.toInt()}$suffix",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        CustomPaint(
          size: const Size(12, 6),
          painter: _TrianglePainter(color),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NowPlayingPlaybackModeSwitch extends StatelessWidget {
  const _NowPlayingPlaybackModeSwitch();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return ListenableBuilder(
      listenable:
          Listenable.merge([playbackService.shuffle, playbackService.playMode]),
      builder: (context, _) {
        final shuffle = playbackService.shuffle.value;
        final playMode = playbackService.playMode.value;

        final modeText = switch (true) {
          _ when shuffle => "随机播放",
          _ when playMode == PlayMode.singleLoop => "单曲循环",
          _ => "顺序播放",
        };

        final icon = switch (true) {
          _ when shuffle => Symbols.shuffle_on,
          _ when playMode == PlayMode.singleLoop => Symbols.repeat_one_on,
          _ => Symbols.repeat,
        };

        return IconButton(
          tooltip: "现在：$modeText",
          onPressed: () {
            if (!shuffle && playMode != PlayMode.singleLoop) {
              playbackService.useShuffle(false);
              playbackService.setPlayMode(PlayMode.singleLoop);
              return;
            }
            if (!shuffle && playMode == PlayMode.singleLoop) {
              playbackService.setPlayMode(PlayMode.forward);
              playbackService.useShuffle(true);
              return;
            }

            playbackService.useShuffle(false);
            playbackService.setPlayMode(PlayMode.forward);
          },
          icon: Icon(icon),
          color: scheme.onSecondaryContainer,
        );
      },
    );
  }
}

/// previous audio, pause/resume, next audio
class _NowPlayingMainControls extends StatelessWidget {
  const _NowPlayingMainControls();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "上一曲",
          onPressed: playbackService.lastAudio,
          icon: const Icon(Symbols.skip_previous),
          style: LargeFilledIconButtonStyle(primary: false, scheme: scheme),
        ),
        const SizedBox(width: 16),
        StreamBuilder(
          stream: playbackService.playerStateStream,
          initialData: playbackService.playerState,
          builder: (context, snapshot) {
            final playerState = snapshot.data!;
            late void Function() onTap;
            if (playerState == PlayerState.playing) {
              onTap = playbackService.pause;
            } else if (playerState == PlayerState.completed) {
              onTap = playbackService.playAgain;
            } else {
              onTap = playbackService.start;
            }

            return IconButton(
              tooltip: playerState == PlayerState.playing ? "暂停" : "播放",
              onPressed: onTap,
              icon: Icon(
                playerState == PlayerState.playing
                    ? Symbols.pause
                    : Symbols.play_arrow,
              ),
              style: LargeFilledIconButtonStyle(primary: true, scheme: scheme),
            );
          },
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: "下一曲",
          onPressed: playbackService.nextAudio,
          icon: const Icon(Symbols.skip_next),
          style: LargeFilledIconButtonStyle(primary: false, scheme: scheme),
        ),
      ],
    );
  }
}

/// suiggly slider, position and length
class _NowPlayingSlider extends StatefulWidget {
  const _NowPlayingSlider();

  @override
  State<_NowPlayingSlider> createState() => _NowPlayingSliderState();
}

class _NowPlayingSliderState extends State<_NowPlayingSlider> {
  final dragPosition = ValueNotifier(0.0);
  bool isDragging = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = context.watch<PlaybackService>();
    final nowPlayingLength = playbackService.length;

    return Column(
      children: [
        SliderTheme(
          data: const SliderThemeData(
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: StreamBuilder(
            stream: playbackService.playerStateStream,
            initialData: playbackService.playerState,
            builder: (context, playerStateSnapshot) => ListenableBuilder(
              listenable: dragPosition,
              builder: (context, _) => StreamBuilder(
                stream: playbackService.positionStream,
                initialData: playbackService.position,
                builder: (context, positionSnapshot) => Slider(
                  thumbColor: scheme.primary,
                  activeColor: scheme.primary,
                  inactiveColor: scheme.outline,
                  min: 0.0,
                  max: nowPlayingLength,
                  value: isDragging
                      ? dragPosition.value
                      : positionSnapshot.data! > nowPlayingLength
                          ? nowPlayingLength
                          : positionSnapshot.data!,
                  label: Duration(
                    milliseconds: (dragPosition.value * 1000).toInt(),
                  ).toStringHMMSS(),
                  onChangeStart: (value) {
                    isDragging = true;
                    dragPosition.value = value;
                  },
                  onChanged: (value) {
                    dragPosition.value = value;
                  },
                  onChangeEnd: (value) {
                    isDragging = false;
                    playbackService.seek(value);
                  },
                ),
                // builder: (context, positionSnapshot) => SquigglySlider(
                //   thumbColor: scheme.primary,
                //   activeColor: scheme.primary,
                //   inactiveColor: scheme.outline,
                //   useLineThumb: true,
                //   squiggleAmplitude:
                //       playerStateSnapshot.data == PlayerState.playing ? 6.0 : 0,
                //   squiggleWavelength: 10.0,
                //   squiggleSpeed: 0.08,
                //   min: 0.0,
                //   max: nowPlayingLength,
                //   value: isDragging
                //       ? dragPosition.value
                //       : positionSnapshot.data! > nowPlayingLength
                //           ? nowPlayingLength
                //           : positionSnapshot.data!,
                //   label: Duration(
                //     milliseconds: (dragPosition.value * 1000).toInt(),
                //   ).toStringHMMSS(),
                //   onChangeStart: (value) {
                //     isDragging = true;
                //     dragPosition.value = value;
                //   },
                //   onChanged: (value) {
                //     dragPosition.value = value;
                //   },
                //   onChangeEnd: (value) {
                //     isDragging = false;
                //     playbackService.seek(value);
                //   },
                // ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder(
                stream: playbackService.positionStream,
                initialData: playbackService.position,
                builder: (context, snapshot) {
                  final pos = snapshot.data!;
                  return Text(
                    Duration(
                      milliseconds: (pos * 1000).toInt(),
                    ).toStringHMMSS(),
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  );
                },
              ),
              Text(
                Duration(
                  milliseconds: (nowPlayingLength * 1000).toInt(),
                ).toStringHMMSS(),
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ],
          ),
        )
      ],
    );
  }
}

/// title, artist, album, cover
class _NowPlayingInfo extends StatefulWidget {
  const _NowPlayingInfo();

  @override
  State<_NowPlayingInfo> createState() => __NowPlayingInfoState();
}

class __NowPlayingInfoState extends State<_NowPlayingInfo> {
  final playbackService = PlayService.instance.playbackService;
  Future<ImageProvider<Object>?>? nowPlayingCover;

  void updateCover() {
    setState(() {
      nowPlayingCover = playbackService.nowPlaying?.largeCover;
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService.addListener(updateCover);
    nowPlayingCover = playbackService.nowPlaying?.largeCover;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nowPlaying = playbackService.nowPlaying;

    final placeholder = FittedBox(
      child: Image.asset(
        'app_icon.ico',
        width: 400.0,
        height: 400.0,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Symbols.broken_image,
          size: 400.0,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );

    const loadingWidget = Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(),
      ),
    );

    return Center(
      child: SizedBox(
        width: 400.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nowPlaying == null ? "Coriander Music" : nowPlaying.title,
              maxLines: 1,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              nowPlaying == null
                  ? "Enjoy Music"
                  : "${nowPlaying.artist} - ${nowPlaying.album}",
              maxLines: 1,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  child: nowPlayingCover == null
                      ? placeholder
                      : FutureBuilder(
                          future: nowPlayingCover,
                          builder: (context, snapshot) =>
                              switch (snapshot.connectionState) {
                            ConnectionState.done => snapshot.data == null
                                ? placeholder
                                : FittedBox(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image(
                                        image: snapshot.data!,
                                        width: 400.0,
                                        height: 400.0,
                                        errorBuilder: (_, __, ___) =>
                                            placeholder,
                                      ),
                                    ),
                                  ),
                            _ => loadingWidget,
                          },
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    playbackService.removeListener(updateCover);
    super.dispose();
  }
}
