import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class NowPlayingPitchControl extends StatelessWidget {
  const NowPlayingPitchControl({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return MenuAnchor(
      builder: (context, controller, child) {
        return IconButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          tooltip: "音调",
          icon: const Icon(Symbols.music_note),
          color: scheme.onSecondaryContainer,
        );
      },
      menuChildren: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!playbackService.isBassFxLoaded)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Text(
                      "BASS_FX missing",
                      style: TextStyle(
                          color: scheme.onErrorContainer, fontSize: 12),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("音调", style: TextStyle(color: scheme.onSurface)),
                    IconButton(
                      icon: const Icon(Symbols.restart_alt, size: 16),
                      onPressed: () => playbackService.setPitch(0.0),
                      tooltip: "重置音调",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                SliderTheme(
                  data: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                  ),
                  child: ValueListenableBuilder(
                    valueListenable: playbackService.pitch,
                    builder: (context, pitchValue, _) => Row(
                      children: [
                        IconButton(
                          onPressed: playbackService.isBassFxLoaded
                              ? () {
                                  final newValue =
                                      (pitchValue - 1.0).clamp(-12.0, 12.0);
                                  playbackService.setPitch(newValue);
                                }
                              : null,
                          icon: const Icon(Symbols.remove),
                          color: scheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Expanded(
                          child: Slider(
                            thumbColor: scheme.primary,
                            activeColor: scheme.primary,
                            inactiveColor: scheme.outline,
                            min: -12.0,
                            max: 12.0,
                            divisions: 24,
                            value: pitchValue,
                            label:
                                "${pitchValue > 0 ? '+' : ''}${pitchValue.toInt()}",
                            onChanged: playbackService.isBassFxLoaded
                                ? (value) {
                                    playbackService.setPitch(value);
                                  }
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed: playbackService.isBassFxLoaded
                              ? () {
                                  final newValue =
                                      (pitchValue + 1.0).clamp(-12.0, 12.0);
                                  playbackService.setPitch(newValue);
                                }
                              : null,
                          icon: const Icon(Symbols.add),
                          color: scheme.onSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
