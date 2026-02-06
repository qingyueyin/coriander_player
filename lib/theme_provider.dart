import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/material.dart';

Color _softenLightSurface(Color color) {
  return Color.alphaBlend(const Color(0xFF000000).withAlpha(14), color);
}

ColorScheme _softenLightScheme(ColorScheme scheme) {
  return scheme.copyWith(
    surface: _softenLightSurface(scheme.surface),
    background: _softenLightSurface(scheme.background),
    surfaceContainerLowest: _softenLightSurface(scheme.surfaceContainerLowest),
    surfaceContainerLow: _softenLightSurface(scheme.surfaceContainerLow),
    surfaceContainer: _softenLightSurface(scheme.surfaceContainer),
    surfaceContainerHigh: _softenLightSurface(scheme.surfaceContainerHigh),
    surfaceContainerHighest: _softenLightSurface(scheme.surfaceContainerHighest),
  );
}

class ThemeProvider extends ChangeNotifier {
  ColorScheme lightScheme = _softenLightScheme(
    ColorScheme.fromSeed(
      seedColor: Color(AppSettings.instance.defaultTheme),
      brightness: Brightness.light,
    ),
  );

  ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: Color(AppSettings.instance.defaultTheme),
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF121314),
    surfaceContainer: const Color(0xFF171819),
    surfaceContainerHigh: const Color(0xFF1A1B1C),
    surfaceContainerHighest: const Color(0xFF1C1D1E),
  );

  String? fontFamily = AppSettings.instance.fontFamily;

  ColorScheme get currScheme =>
      themeMode == ThemeMode.dark ? darkScheme : lightScheme;

  ThemeMode themeMode = AppSettings.instance.themeMode;
  final Map<String, ColorScheme> _schemeCache = {};
  final Map<String, Future<ColorScheme>> _schemeFutureCache = {};
  int _themeRequestToken = 0;

  static ThemeProvider? _instance;

  ThemeProvider._();

  static ThemeProvider get instance {
    _instance ??= ThemeProvider._();
    return _instance!;
  }

  void applyTheme({required Color seedColor}) {
    lightScheme = _softenLightScheme(ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ));

    darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF121314),
      surfaceContainer: const Color(0xFF171819),
      surfaceContainerHigh: const Color(0xFF1A1B1C),
      surfaceContainerHighest: const Color(0xFF1C1D1E),
    );
    notifyListeners();

    PlayService.instance.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;

      PlayService.instance.desktopLyricService.sendThemeMessage(currScheme);
    });
  }

  /// 应用从 image 生成的主题。只在 themeMode == this.themeMode 时通知改变。
  void applyThemeFromImage(
    ImageProvider image,
    ThemeMode themeMode, {
    String? cacheKey,
    int? requestToken,
  }) {
    final brightness = switch (themeMode) {
      ThemeMode.system => Brightness.light,
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
    };

    final key = cacheKey == null ? null : "$cacheKey|${brightness.name}";
    final cached = key == null ? null : _schemeCache[key];
    if (cached != null) {
      switch (brightness) {
        case Brightness.light:
          lightScheme = _softenLightScheme(cached);
          break;
        case Brightness.dark:
          darkScheme = cached.copyWith(
            surface: const Color(0xFF121314),
            surfaceContainer: const Color(0xFF171819),
            surfaceContainerHigh: const Color(0xFF1A1B1C),
            surfaceContainerHighest: const Color(0xFF1C1D1E),
          );
          break;
      }

      if (themeMode == this.themeMode &&
          (requestToken == null || requestToken == _themeRequestToken)) {
        notifyListeners();
        PlayService.instance.desktopLyricService.canSendMessage.then((canSend) {
          if (!canSend) return;
          PlayService.instance.desktopLyricService.sendThemeMessage(currScheme);
        });
      }
      return;
    }

    final future = key == null
        ? ColorScheme.fromImageProvider(provider: image, brightness: brightness)
        : _schemeFutureCache.putIfAbsent(
            key,
            () => ColorScheme.fromImageProvider(
              provider: image,
              brightness: brightness,
            ),
          );

    future.then((value) {
      if (key != null) {
        _schemeFutureCache.remove(key);
        _schemeCache[key] = value;
      }

      if (requestToken != null && requestToken != _themeRequestToken) return;

      switch (brightness) {
        case Brightness.light:
          lightScheme = _softenLightScheme(value);
          break;
        case Brightness.dark:
          darkScheme = value.copyWith(
            surface: const Color(0xFF121314),
            surfaceContainer: const Color(0xFF171819),
            surfaceContainerHigh: const Color(0xFF1A1B1C),
            surfaceContainerHighest: const Color(0xFF1C1D1E),
          );
          break;
      }

      if (themeMode == this.themeMode) {
        notifyListeners();
        PlayService.instance.desktopLyricService.canSendMessage.then((canSend) {
          if (!canSend) return;
          PlayService.instance.desktopLyricService.sendThemeMessage(currScheme);
        });
      }
    });
  }

  void applyThemeMode(ThemeMode themeMode) {
    this.themeMode = themeMode;
    notifyListeners();
    PlayService.instance.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;

      PlayService.instance.desktopLyricService.sendThemeMessage(currScheme);
      PlayService.instance.desktopLyricService.sendThemeModeMessage(
        themeMode == ThemeMode.dark,
      );
    });
  }

  void applyThemeFromAudio(Audio audio) {
    if (!AppSettings.instance.dynamicTheme) return;
    _themeRequestToken += 1;
    final token = _themeRequestToken;

    audio.cover.then((image) {
      if (image == null) return;

      applyThemeFromImage(
        image,
        themeMode,
        cacheKey: audio.path,
        requestToken: token,
      );

      final second = switch (themeMode) {
        ThemeMode.system => ThemeMode.dark,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.light,
      };
      applyThemeFromImage(
        image,
        second,
        cacheKey: audio.path,
        requestToken: token,
      );
    });
  }

  void changeFontFamily(String? fontFamily) {
    this.fontFamily = fontFamily;
    notifyListeners();
  }

  static const double radiusSmall = 6.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 3.0;
  static const double elevationHigh = 6.0;

  // ButtonStyle get primaryButtonStyle => ButtonStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.primary),
  //       foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
  //       fixedSize: const WidgetStatePropertyAll(Size.fromHeight(40.0)),
  //       overlayColor:
  //           WidgetStatePropertyAll(scheme.onPrimary.withOpacity(0.08)),
  //     );

  // ButtonStyle get secondaryButtonStyle => ButtonStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.secondaryContainer),
  //       foregroundColor: WidgetStatePropertyAll(scheme.onSecondaryContainer),
  //       fixedSize: const WidgetStatePropertyAll(Size.fromHeight(40.0)),
  //       overlayColor: WidgetStatePropertyAll(
  //           scheme.onSecondaryContainer.withOpacity(0.08)),
  //     );

  // ButtonStyle get primaryIconButtonStyle => ButtonStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.primary),
  //       foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
  //       overlayColor: WidgetStatePropertyAll(
  //         scheme.onPrimary.withOpacity(0.08),
  //       ),
  //     );

  // ButtonStyle get secondaryIconButtonStyle => ButtonStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.secondaryContainer),
  //       foregroundColor: WidgetStatePropertyAll(scheme.onSecondaryContainer),
  //       overlayColor: WidgetStatePropertyAll(
  //         scheme.onSecondaryContainer.withOpacity(0.08),
  //       ),
  //     );

  // ButtonStyle get menuItemStyle => ButtonStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.secondaryContainer),
  //       foregroundColor: WidgetStatePropertyAll(scheme.onSecondaryContainer),
  //       padding: const WidgetStatePropertyAll(
  //         EdgeInsets.symmetric(horizontal: 16.0),
  //       ),
  //       overlayColor: WidgetStatePropertyAll(
  //         scheme.onSecondaryContainer.withOpacity(0.08),
  //       ),
  //     );

  // MenuStyle get menuStyleWithFixedSize => MenuStyle(
  //       backgroundColor: WidgetStatePropertyAll(scheme.secondaryContainer),
  //       surfaceTintColor: WidgetStatePropertyAll(scheme.secondaryContainer),
  //       shape: WidgetStatePropertyAll(RoundedRectangleBorder(
  //         borderRadius: BorderRadius.circular(20.0),
  //       )),
  //       fixedSize: const WidgetStatePropertyAll(Size.fromWidth(149.0)),
  //     );

  // MenuStyle get menuStyle => MenuStyle(
  //       shape: WidgetStatePropertyAll(
  //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  //       ),
  //       backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
  //       surfaceTintColor: WidgetStatePropertyAll(scheme.surfaceContainer),
  //     );

  // InputDecoration inputDecoration(String labelText) => InputDecoration(
  //       enabledBorder: OutlineInputBorder(
  //         borderSide: BorderSide(color: scheme.outline, width: 2),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderSide: BorderSide(color: scheme.primary, width: 2),
  //       ),
  //       labelText: labelText,
  //       labelStyle: TextStyle(color: scheme.onSurfaceVariant),
  //       floatingLabelStyle: TextStyle(color: scheme.primary),
  //       focusColor: scheme.primary,
  //     );
}
