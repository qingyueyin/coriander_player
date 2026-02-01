import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

class ImmersiveModeController with ChangeNotifier, WindowListener {
  ImmersiveModeController._();

  static final ImmersiveModeController instance = ImmersiveModeController._();

  bool _enabled = false;
  bool get enabled => _enabled;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    windowManager.addListener(this);
    final full = await windowManager.isFullScreen();
    _setEnabled(full);
  }

  Future<void> enter() async {
    await windowManager.setFullScreen(true);
    _setEnabled(true);
  }

  Future<void> exit() async {
    await windowManager.setFullScreen(false);
    _setEnabled(false);
  }

  Future<void> toggle() async {
    final full = await windowManager.isFullScreen();
    if (full) {
      await exit();
    } else {
      await enter();
    }
  }

  void _setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  @override
  void onWindowEnterFullScreen() {
    _setEnabled(true);
  }

  @override
  void onWindowLeaveFullScreen() {
    _setEnabled(false);
  }
}

