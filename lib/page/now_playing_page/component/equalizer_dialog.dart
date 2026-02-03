import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/utils.dart';
import 'package:filepicker_windows/filepicker_windows.dart';
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
  static const _eqFreqs = [
    31.0,
    62.0,
    125.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
    4000.0,
    8000.0,
    16000.0
  ];

  @override
  void initState() {
    super.initState();
    _gains = List.from(PlayService.instance.playbackService.eqGains);
  }

  Future<void> _importWaveletEq() async {
    final file = OpenFilePicker()
      ..filterSpecification = {
        'Wavelet AutoEq Files (*.txt)': '*.txt',
        'All Files (*.*)': '*.*'
      }
      ..defaultFilterIndex = 0
      ..defaultExtension = 'txt'
      ..title = 'Select Wavelet GraphicEQ.txt';

    final result = file.getFile();
    if (result != null) {
      try {
        final content = await result.readAsString();
        final fileName = result.path.split('\\').last.replaceAll('.txt', '');
        _parseWaveletEq(content, fileName);
      } catch (e) {
        if (mounted) {
          showTextOnSnackBar("Import failed: $e");
        }
      }
    }
  }

  void _parseWaveletEq(String content, String presetName) {
    // Wavelet format: "GraphicEQ: 20 -6.9; 21 -6.9; ..."
    // Or sometimes just lines of "Freq Gain" or "Freq: Gain"
    // We will support "GraphicEQ:" prefix format as it is standard AutoEq export for Wavelet
    String data = content;
    if (content.startsWith("GraphicEQ:")) {
      data = content.substring(10).trim();
    }

    final points = <MapEntry<double, double>>[];
    final pairs = data.split(';');
    for (var pair in pairs) {
      pair = pair.trim();
      if (pair.isEmpty) continue;

      // Handle "Freq Gain" (space separated)
      final parts = pair.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final freq = double.tryParse(parts[0]);
        final gain = double.tryParse(parts[1]);
        if (freq != null && gain != null) {
          points.add(MapEntry(freq, gain));
        }
      }
    }

    if (points.isEmpty) {
      if (mounted) showTextOnSnackBar("No valid EQ data found");
      return;
    }

    // Sort by frequency
    points.sort((a, b) => a.key.compareTo(b.key));

    // Map to our 10 bands using linear interpolation
    final newGains = List<double>.filled(10, 0.0);
    for (int i = 0; i < 10; i++) {
      final centerFreq = _eqFreqs[i];
      newGains[i] = _interpolateGain(centerFreq, points);
      // Clamp to -15 ~ 15
      newGains[i] = newGains[i].clamp(-15.0, 15.0);
    }

    setState(() {
      _gains = newGains;
    });

    // Apply
    for (int i = 0; i < 10; i++) {
      PlayService.instance.playbackService.setEQ(i, _gains[i]);
    }
    PlayService.instance.playbackService.savePreference();

    // Auto save as preset
    PlayService.instance.playbackService.saveEqPreset(presetName);

    if (mounted) {
      showTextOnSnackBar("Imported & Saved '$presetName'");
    }
  }

  double _interpolateGain(
      double targetFreq, List<MapEntry<double, double>> points) {
    // Find closest points
    if (targetFreq <= points.first.key) return points.first.value;
    if (targetFreq >= points.last.key) return points.last.value;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      if (targetFreq >= p1.key && targetFreq <= p2.key) {
        // Linear interpolation
        final t = (targetFreq - p1.key) / (p2.key - p1.key);
        return p1.value + (p2.value - p1.value) * t;
      }
    }
    return 0.0;
  }

  void _savePreset() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Preset"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Preset Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                PlayService.instance.playbackService
                    .saveEqPreset(controller.text);
                Navigator.of(context).pop();
                setState(() {}); // Refresh UI
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _applyPreset(EqPreset preset) {
    PlayService.instance.playbackService.applyEqPreset(preset);
    setState(() {
      _gains = List.from(preset.gains);
    });
  }

  void _deletePreset(EqPreset preset) {
    PlayService.instance.playbackService.removeEqPreset(preset.name);
    setState(() {}); // Refresh UI
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final playbackService = PlayService.instance.playbackService;
    final presets = playbackService.eqPresets;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Symbols.graphic_eq),
          const SizedBox(width: 12),
          const Text("均衡器"),
          const Spacer(),
          // Presets Menu
          MenuAnchor(
            builder: (context, controller, child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                tooltip: "Presets",
                icon: const Icon(Symbols.queue_music),
              );
            },
            menuChildren: [
              if (presets.isEmpty)
                const MenuItemButton(
                  onPressed: null,
                  child: Text("No presets"),
                ),
              ...presets.map(
                (preset) => MenuItemButton(
                  onPressed: () => _applyPreset(preset),
                  trailingIcon: IconButton(
                    onPressed: () => _deletePreset(preset),
                    icon: const Icon(Symbols.close, size: 16),
                    tooltip: "Delete",
                  ),
                  child: Text(preset.name),
                ),
              ),
              const Divider(),
              MenuItemButton(
                onPressed: _savePreset,
                leadingIcon: const Icon(Symbols.save),
                child: const Text("Save current as preset..."),
              ),
            ],
          ),
          IconButton(
            onPressed: _importWaveletEq,
            tooltip: "Import Wavelet AutoEq",
            icon: const Icon(Symbols.file_upload),
          ),
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
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14.0),
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
                        onChangeEnd: (value) {
                          playbackService.savePreference();
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
            playbackService.savePreference();
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
