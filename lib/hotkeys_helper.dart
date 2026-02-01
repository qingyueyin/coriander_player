import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/src/bass/bass_player.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

class HotkeysHelper {
  static final Map<HotKey, void Function(HotKey)> _hotKeys = {
    HotKey(key: PhysicalKeyboardKey.space, scope: HotKeyScope.inapp): (_) {
      final playbackService = PlayService.instance.playbackService;
      final state = playbackService.playerState;
      if (state == PlayerState.playing) {
        playbackService.pause();
        showHotkeyToast(text: "暂停", icon: Icons.pause);
      } else if (state == PlayerState.completed) {
        playbackService.playAgain();
        showHotkeyToast(text: "重播", icon: Icons.replay);
      } else {
        playbackService.start();
        showHotkeyToast(text: "播放", icon: Icons.play_arrow);
      }
    },
    HotKey(key: PhysicalKeyboardKey.escape, scope: HotKeyScope.inapp): (_) {
      final routerContext = ROUTER_KEY.currentContext;
      if (routerContext == null) return;

      // 先关闭弹窗，再返回上一级页面
      final navigator = Navigator.maybeOf(routerContext);
      if (navigator?.canPop() == true) {
        navigator?.pop();
      } else if (ROUTER_KEY.currentContext?.canPop() == true) {
        ROUTER_KEY.currentContext?.pop();
      }
    },
    HotKey(
      key: PhysicalKeyboardKey.arrowLeft,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    ): (_) {
      PlayService.instance.playbackService.lastAudio();
      showHotkeyToast(text: "上一曲", icon: Icons.skip_previous);
    },
    HotKey(
      key: PhysicalKeyboardKey.arrowRight,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    ): (_) {
      PlayService.instance.playbackService.nextAudio();
      showHotkeyToast(text: "下一曲", icon: Icons.skip_next);
    },
    HotKey(
      key: PhysicalKeyboardKey.arrowUp,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    ): (_) {
      final playbackService = PlayService.instance.playbackService;
      final next = (playbackService.volumeDsp + 0.05).clamp(0.0, 1.0);
      playbackService.setVolumeDsp(next);
      showHotkeyToast(
        text: "应用音量：${(next * 100).round()}%",
        icon: Icons.volume_up,
      );
    },
    HotKey(
      key: PhysicalKeyboardKey.arrowDown,
      modifiers: [HotKeyModifier.control],
      scope: HotKeyScope.inapp,
    ): (_) {
      final playbackService = PlayService.instance.playbackService;
      final next = (playbackService.volumeDsp - 0.05).clamp(0.0, 1.0);
      playbackService.setVolumeDsp(next);
      showHotkeyToast(
        text: "应用音量：${(next * 100).round()}%",
        icon: Icons.volume_down,
      );
    },
    HotKey(key: PhysicalKeyboardKey.f1, scope: HotKeyScope.inapp): (_) async {
      final full = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!full);
      showHotkeyToast(text: "全屏：${full ? "关" : "开"}", icon: Icons.fullscreen);
    },
  };

  static void registerHotKeys() {
    for (var item in _hotKeys.entries) {
      hotKeyManager.register(
        item.key,
        keyDownHandler: item.value,
      );
    }
  }

  static Future<void> unregisterAll() => hotKeyManager.unregisterAll();

  static Future<void> onFocusChanges(focus) async {
    if (focus) {
      await unregisterAll();
    } else {
      registerHotKeys();
    }
  }
}
