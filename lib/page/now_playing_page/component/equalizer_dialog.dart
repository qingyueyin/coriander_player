import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class EqualizerDialog extends StatefulWidget {
  const EqualizerDialog({super.key});

  @override
  State<EqualizerDialog> createState() => _EqualizerDialogState();
}

class _EqualizerDialogState extends State<EqualizerDialog> {
  late List<double> _gains;
  static const _eqCenters = [
    "31",
    "62",
    "125",
    "250",
    "500",
    "1k",
    "2k",
    "4k",
    "8k",
    "16k"
  ];

  @override
  void initState() {
    super.initState();
    _gains = List.from(PlayService.instance.playbackService.eqGains);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Symbols.graphic_eq),
          const SizedBox(width: 12),
          const Text("均衡器"),
          const Spacer(),
          if (!playbackService.isBassFxLoaded)
            Tooltip(
              message: "BASS_FX not loaded",
              child: Icon(Symbols.error, color: scheme.error),
            ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 300,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(10, (index) {
            return Column(
              children: [
                Text(
                  "${_gains[index].toInt()}",
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6.0),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14.0),
                      ),
                      child: Slider(
                        min: -15.0,
                        max: 15.0,
                        value: _gains[index],
                        onChanged: (value) {
                          setState(() {
                            _gains[index] = value;
                          });
                          playbackService.setEQ(index, value);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _eqCenters[index],
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            );
          }),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _gains = List.filled(10, 0.0);
            });
            for (int i = 0; i < 10; i++) {
              playbackService.setEQ(i, 0.0);
            }
          },
          child: const Text("重置"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("关闭"),
        ),
      ],
    );
  }
}
