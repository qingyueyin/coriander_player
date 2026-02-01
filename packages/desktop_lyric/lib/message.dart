import 'dart:convert';

String getMessageTypeName<T>() {
  if (T == InitArgsMessage) return 'InitArgsMessage';
  if (T == ControlEventMessage) return 'ControlEventMessage';
  if (T == UnlockMessage) return 'UnlockMessage';
  if (T == ThemeModeChangedMessage) return 'ThemeModeChangedMessage';
  if (T == ThemeChangedMessage) return 'ThemeChangedMessage';
  if (T == PlayerStateChangedMessage) return 'PlayerStateChangedMessage';
  if (T == NowPlayingChangedMessage) return 'NowPlayingChangedMessage';
  if (T == LyricLineChangedMessage) return 'LyricLineChangedMessage';
  return T.toString();
}

abstract class Message {
  String get type;
  Map<String, dynamic> get message;

  Map<String, dynamic> toJson() => {'type': type, 'message': message};

  String buildMessageJson() => json.encode(toJson());
}

class InitArgsMessage extends Message {
  final bool isPlaying;
  final String title;
  final String artist;
  final String album;
  final bool isDarkMode;
  final int primaryArgb;
  final int surfaceContainerArgb;
  final int onSurfaceArgb;

  InitArgsMessage(
    this.isPlaying,
    this.title,
    this.artist,
    this.album,
    this.isDarkMode,
    this.primaryArgb,
    this.surfaceContainerArgb,
    this.onSurfaceArgb,
  );

  @override
  String get type => getMessageTypeName<InitArgsMessage>();

  @override
  Map<String, dynamic> get message => {
        'isPlaying': isPlaying,
        'title': title,
        'artist': artist,
        'album': album,
        'isDarkMode': isDarkMode,
        'primaryArgb': primaryArgb,
        'surfaceContainerArgb': surfaceContainerArgb,
        'onSurfaceArgb': onSurfaceArgb,
      };
}

enum ControlEvent {
  pause,
  start,
  previousAudio,
  nextAudio,
  lock,
  close,
}

class ControlEventMessage extends Message {
  final ControlEvent event;

  ControlEventMessage(this.event);

  factory ControlEventMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['event'];
    if (raw is String) {
      return ControlEventMessage(ControlEvent.values.byName(raw));
    }
    if (raw is int) {
      return ControlEventMessage(ControlEvent.values[raw]);
    }
    throw FormatException('Invalid event: $raw');
  }

  @override
  String get type => getMessageTypeName<ControlEventMessage>();

  @override
  Map<String, dynamic> get message => {'event': event.name};
}

class UnlockMessage extends Message {
  UnlockMessage();

  @override
  String get type => getMessageTypeName<UnlockMessage>();

  @override
  Map<String, dynamic> get message => const {};
}

class ThemeModeChangedMessage extends Message {
  final bool darkMode;

  ThemeModeChangedMessage(this.darkMode);

  @override
  String get type => getMessageTypeName<ThemeModeChangedMessage>();

  @override
  Map<String, dynamic> get message => {'darkMode': darkMode};
}

class ThemeChangedMessage extends Message {
  final int primaryArgb;
  final int surfaceContainerArgb;
  final int onSurfaceArgb;

  ThemeChangedMessage(
    this.primaryArgb,
    this.surfaceContainerArgb,
    this.onSurfaceArgb,
  );

  @override
  String get type => getMessageTypeName<ThemeChangedMessage>();

  @override
  Map<String, dynamic> get message => {
        'primaryArgb': primaryArgb,
        'surfaceContainerArgb': surfaceContainerArgb,
        'onSurfaceArgb': onSurfaceArgb,
      };
}

class PlayerStateChangedMessage extends Message {
  final bool isPlaying;

  PlayerStateChangedMessage(this.isPlaying);

  @override
  String get type => getMessageTypeName<PlayerStateChangedMessage>();

  @override
  Map<String, dynamic> get message => {'isPlaying': isPlaying};
}

class NowPlayingChangedMessage extends Message {
  final String title;
  final String artist;
  final String album;

  NowPlayingChangedMessage(this.title, this.artist, this.album);

  @override
  String get type => getMessageTypeName<NowPlayingChangedMessage>();

  @override
  Map<String, dynamic> get message => {
        'title': title,
        'artist': artist,
        'album': album,
      };
}

class LyricLineChangedMessage extends Message {
  final String content;
  final Duration length;
  final String? translation;

  LyricLineChangedMessage(this.content, this.length, this.translation);

  @override
  String get type => getMessageTypeName<LyricLineChangedMessage>();

  @override
  Map<String, dynamic> get message => {
        'content': content,
        'lengthMs': length.inMilliseconds,
        'translation': translation,
      };
}
