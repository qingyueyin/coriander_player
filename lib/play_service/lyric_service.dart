import 'dart:async';
import 'dart:math';

import 'package:coriander_player/app_settings.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/lyric_source.dart';
import 'package:coriander_player/music_matcher.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:flutter/foundation.dart';

/// 只通知 lyric 变更
class LyricService extends ChangeNotifier {
  final PlayService playService;

  late StreamSubscription _positionStreamSubscription;
  double _lastPos = 0.0;
  Lyric? _currLyric;
  List<int> _lineStartMs = const [];
  LyricService(this.playService) {
    _positionStreamSubscription =
        playService.playbackService.positionStream.listen((pos) {
      final jumped = (pos - _lastPos).abs() > 1.0;
      _lastPos = pos;
      if (jumped) {
        findCurrLyricLineAt(pos);
        return;
      }
      final lyric = _currLyric;
      if (lyric == null) return;
      if (_nextLyricLine >= lyric.lines.length) return;

      final posMs = (pos * 1000).round();
      while (_nextLyricLine < _lineStartMs.length &&
          posMs > _lineStartMs[_nextLyricLine]) {
        _nextLyricLine += 1;
      }

      final currLineIndex = _nextLyricLine - 1;
      if (currLineIndex < 0 || currLineIndex >= lyric.lines.length) return;
      _lyricLineStreamController.add(currLineIndex);

      playService.desktopLyricService.canSendMessage.then((canSend) {
        if (!canSend) return;
        playService.desktopLyricService.sendLyricLineMessage(
          lyric.lines[currLineIndex],
        );
      });
    });
  }

  Audio? _getNowPlaying() => playService.playbackService.nowPlaying;

  /// 供 widget 使用
  Future<Lyric?> currLyricFuture = Future.value(null);

  /// 下一行歌词
  int _nextLyricLine = 0;

  late final StreamController<int> _lyricLineStreamController =
      StreamController.broadcast(onListen: () {
    _lyricLineStreamController.add(_nextLyricLine);
  });

  Stream<int> get lyricLineStream => _lyricLineStreamController.stream;

  /// 重新计算歌词进行到第几行
  void findCurrLyricLine() {
    findCurrLyricLineAt(playService.playbackService.position);
  }

  void findCurrLyricLineAt(double positionSeconds) {
    final lyric = _currLyric;
    if (lyric == null) {
      currLyricFuture.then((value) {
        if (value == null) return;
        _setCurrLyric(value);
        findCurrLyricLineAt(positionSeconds);
      });
      return;
    }

    final posMs = (positionSeconds * 1000).round();
    final next = _lowerBoundGreater(_lineStartMs, posMs);
    _nextLyricLine = next == -1 ? lyric.lines.length : next;
    final currLineIndex = max(_nextLyricLine - 1, 0);
    _lyricLineStreamController.add(currLineIndex);

    if (currLineIndex < 0 || currLineIndex >= lyric.lines.length) return;
    playService.desktopLyricService.canSendMessage.then((canSend) {
      if (!canSend) return;
      playService.desktopLyricService.sendLyricLineMessage(
        lyric.lines[currLineIndex],
      );
    });
  }

  int _lowerBoundGreater(List<int> arr, int x) {
    if (arr.isEmpty) return -1;
    int lo = 0;
    int hi = arr.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (arr[mid] > x) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    return lo >= arr.length ? -1 : lo;
  }

  void _setCurrLyric(Lyric lyric) {
    _currLyric = lyric;
    _lineStartMs = lyric.lines.map((e) => e.start.inMilliseconds).toList();
  }

  Future<Lyric?> _getLyricDefault(bool localFirst) async {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return Future.value(null);

    if (localFirst) {
      return (await Lrc.fromAudioPath(nowPlaying)) ??
          (await getMostMatchedLyric(nowPlaying));
    }
    return (await getMostMatchedLyric(nowPlaying)) ??
        (await Lrc.fromAudioPath(nowPlaying));
  }

  /// 根据默认歌词来源获取歌词：
  /// 1. 如果没有指定来源，按照现在的方式寻找歌词（本地优先或在线优先）
  /// 2. 如果指定来源，按照指定的来源获取
  void updateLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    _currLyric = null;
    _lineStartMs = const [];

    final lyricSource = LYRIC_SOURCES[nowPlaying.path];
    if (lyricSource == null) {
      currLyricFuture = _getLyricDefault(AppSettings.instance.localLyricFirst);
    } else {
      if (lyricSource.source == LyricSourceType.local) {
        currLyricFuture = Lrc.fromAudioPath(nowPlaying);
      } else {
        currLyricFuture = getOnlineLyric(
          qqSongId: lyricSource.qqSongId,
          kugouSongHash: lyricSource.kugouSongHash,
          neteaseSongId: lyricSource.neteaseSongId,
        );
      }
    }

    currLyricFuture.then((value) {
      if (value == null) return;
      _nextLyricLine = 0;
      _setCurrLyric(value);
      findCurrLyricLineAt(playService.playbackService.position);
    });

    notifyListeners();
  }

  void useLocalLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    _currLyric = null;
    _lineStartMs = const [];

    currLyricFuture = Lrc.fromAudioPath(nowPlaying);
    currLyricFuture.then((value) {
      if (value == null) return;
      _setCurrLyric(value);
      findCurrLyricLine();
    });

    notifyListeners();
  }

  void useOnlineLyric() {
    final nowPlaying = _getNowPlaying();
    if (nowPlaying == null) return;

    currLyricFuture.ignore();
    _currLyric = null;
    _lineStartMs = const [];

    currLyricFuture = getMostMatchedLyric(nowPlaying);
    currLyricFuture.then((value) {
      if (value == null) return;
      _setCurrLyric(value);
      findCurrLyricLine();
    });

    notifyListeners();
  }

  void useSpecificLyric(Lyric lyric) {
    currLyricFuture.ignore();

    currLyricFuture = Future.value(lyric);
    currLyricFuture.then((value) {
      if (value == null) return;
      _setCurrLyric(value);
      findCurrLyricLine();
    });

    notifyListeners();
  }

  @override
  void dispose() {
    _lyricLineStreamController.close();
    _positionStreamSubscription.cancel();
    super.dispose();
  }
}
