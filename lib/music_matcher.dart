import 'dart:convert';
import 'dart:math';

import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/lyric/krc.dart';
import 'package:coriander_player/lyric/lrc.dart';
import 'package:coriander_player/lyric/lyric.dart';
import 'package:coriander_player/lyric/qrc.dart';
import 'package:coriander_player/utils.dart';
import 'package:music_api/api/kugou/kugou.dart';
import 'package:music_api/api/netease/netease.dart';
import 'package:music_api/api/qq/qq.dart';
import 'package:path/path.dart' as p;

enum ResultSource { qq, kugou, netease }

String _normalizeKeyword(String raw) {
  final s = raw
      .replaceAll(RegExp(r'\.(flac|mp3|wav|m4a|aac|ogg|opus|ape)$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[_\.·]+'), ' ')
      .replaceAll(RegExp(r'[‐‑‒–—−]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.toLowerCase();
}

int _prefixMatchScore(String a, String b) {
  final len = min(a.length, b.length);
  int score = 0;
  for (int i = 0; i < len; ++i) {
    if (a[i] == b[i]) {
      score += 1;
    } else {
      break;
    }
  }
  return score;
}

String _audioFileStem(Audio audio) {
  try {
    return _normalizeKeyword(p.basenameWithoutExtension(audio.path));
  } catch (_) {
    return '';
  }
}

double _computeScore(Audio audio, String title, String artists, String album) {
  final audioTitle = _normalizeKeyword(audio.title);
  final audioArtist = _normalizeKeyword(audio.artist);
  final audioAlbum = _normalizeKeyword(audio.album);
  final audioStem = _audioFileStem(audio);

  final resultTitle = _normalizeKeyword(title);
  final resultArtists = _normalizeKeyword(artists);
  final resultAlbum = _normalizeKeyword(album);

  int score = 0;
  int maxScore = 0;

  score += _prefixMatchScore(audioTitle, resultTitle);
  maxScore += audioTitle.length;

  score += _prefixMatchScore(audioArtist, resultArtists);
  maxScore += audioArtist.length;

  score += _prefixMatchScore(audioAlbum, resultAlbum);
  maxScore += audioAlbum.length;

  if (audioStem.isNotEmpty) {
    score += (_prefixMatchScore(audioStem, resultTitle) * 2);
    maxScore += (audioStem.length * 2);
  }

  if (maxScore <= 0) return 0.0;
  return score / maxScore;
}

List<String> _buildQueryCandidates(Audio audio) {
  final title = _normalizeKeyword(audio.title);
  final artist = _normalizeKeyword(audio.artist);
  final stem = _audioFileStem(audio);

  final set = <String>{};
  if (title.isNotEmpty && artist.isNotEmpty && artist != 'unknown') {
    set.add('$title $artist'.trim());
  }
  if (title.isNotEmpty) {
    set.add(title);
  }
  if (stem.isNotEmpty && stem != title) {
    set.add(stem);
  }

  if (stem.contains(' - ')) {
    final parts = stem.split(' - ').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      set.add(parts.last);
      set.add('${parts.last} ${parts.first}'.trim());
    }
  }

  return set.where((q) => q.isNotEmpty).toList();
}

class SongSearchResult {
  ResultSource source;
  String title;
  String artists;
  String album;
  double score;

  /// for qq result
  int? qqSongId;

  /// for netease result
  String? neteaseSongId;

  /// for kugou result
  String? kugouSongHash;

  SongSearchResult(
      this.source, this.title, this.artists, this.album, this.score,
      {this.qqSongId, this.neteaseSongId, this.kugouSongHash});

  @override
  String toString() {
    return json.encode({
      "source": source.toString(),
      "title": title,
      "artists": artists,
      "album": album,
      "score": score,
    });
  }

  static SongSearchResult fromQQSearchResult(Map itemSong, Audio audio) {
    final List singer = itemSong["singer"];
    final buffer = StringBuffer(singer.first["name"]);
    for (int i = 1; i < singer.length; ++i) {
      buffer.write("、${singer[i]["name"]}");
    }

    final title = itemSong["name"] ?? "";
    final album = itemSong["album"]["title"] ?? "";
    final artists = buffer.toString();

    return SongSearchResult(
      ResultSource.qq,
      title,
      artists,
      album,
      _computeScore(audio, title, artists, album),
      qqSongId: itemSong["id"],
    );
  }

  static SongSearchResult fromNeteaseSearchResult(Map song, Audio audio) {
    final title = song["name"] ?? "";

    final List artistList = song["artists"];
    final buffer = StringBuffer(artistList.first["name"]);
    for (int i = 1; i < artistList.length; ++i) {
      buffer.write("、${artistList[i]["name"]}");
    }
    final artists = buffer.toString();

    final album = song["album"]["name"] ?? "";

    return SongSearchResult(
      ResultSource.netease,
      title,
      artists,
      album,
      _computeScore(audio, title, artists, album),
      neteaseSongId: song["id"].toString(),
    );
  }

  static SongSearchResult fromKugouSearchResult(Map info, Audio audio) {
    final title = info["songname"];
    final album = info["album_name"];
    final artists = info["singername"];

    return SongSearchResult(
      ResultSource.kugou,
      title,
      artists,
      album,
      _computeScore(audio, title, artists, album),
      kugouSongHash: info["hash"],
    );
  }
}

Future<List<SongSearchResult>> _uniSearchOnce(Audio audio, String query) async {
  List<SongSearchResult> result = [];

  final Map kugouAnswer = (await KuGou.searchSong(keyword: query)).data;
  final List kugouResultList = kugouAnswer["data"]["info"];
  for (int j = 0; j < kugouResultList.length; j++) {
    if (j >= 5) break;
    result.add(SongSearchResult.fromKugouSearchResult(
      kugouResultList[j],
      audio,
    ));
  }

  final Map neteaseAnswer = (await Netease.search(keyWord: query)).data;
  final List neteaseResultList = neteaseAnswer["result"]["songs"];
  for (int k = 0; k < neteaseResultList.length; k++) {
    if (k >= 5) break;
    result.add(SongSearchResult.fromNeteaseSearchResult(
      neteaseResultList[k],
      audio,
    ));
  }

  final Map qqAnswer = (await QQ.search(keyWord: query)).data;
  final List qqResultList = qqAnswer["req"]["data"]["body"]["item_song"];
  for (int i = 0; i < qqResultList.length; i++) {
    if (i >= 5) break;
    result.add(SongSearchResult.fromQQSearchResult(
      qqResultList[i],
      audio,
    ));
  }

  return result;
}

Future<List<SongSearchResult>> uniSearch(Audio audio) async {
  final queries = _buildQueryCandidates(audio);
  try {
    final merged = <String, SongSearchResult>{};
    double bestScore = 0.0;

    for (final query in queries) {
      final batch = await _uniSearchOnce(audio, query);
      for (final item in batch) {
        final key = switch (item.source) {
          ResultSource.qq => 'qq:${item.qqSongId ?? '${item.title}|${item.artists}|${item.album}'}',
          ResultSource.netease => 'netease:${item.neteaseSongId ?? '${item.title}|${item.artists}|${item.album}'}',
          ResultSource.kugou => 'kugou:${item.kugouSongHash ?? '${item.title}|${item.artists}|${item.album}'}',
        };
        final existing = merged[key];
        if (existing == null || item.score > existing.score) {
          merged[key] = item;
        }
        if (item.score > bestScore) bestScore = item.score;
      }
      if (bestScore >= 0.52) {
        break;
      }
    }

    final result = merged.values.toList();
    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  } catch (err, trace) {
    LOGGER.e("queries: $queries");
    LOGGER.e(err, stackTrace: trace);
  }
  return Future.value([]);
}

Future<Lrc?> _getNeteaseUnsyncLyric(String neteaseSongId) async {
  try {
    final answer = await Netease.lyric(id: neteaseSongId);
    final lrcText = answer.data["lrc"]["lyric"];
    if (lrcText is String) {
      final lrcTrans = answer.data["tlyric"]["lyric"];
      return Lrc.fromLrcText(
        lrcText + lrcTrans,
        LrcSource.web,
        separator: "┃",
      );
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Qrc?> _getQQSyncLyric(int qqSongId) async {
  try {
    final answer = await QQ.songLyric3(songId: qqSongId);
    final qrcText = answer.data["lyric"];
    if (qrcText is String) {
      final qrcTransRawStr = answer.data["trans"];
      if (qrcTransRawStr is String) {
        return Qrc.fromQrcText(qrcText, qrcTransRawStr);
      }
      return Qrc.fromQrcText(qrcText);
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Krc?> _getKugouSyncLyric(String kugouSongHash) async {
  try {
    final answer = await KuGou.krc(hash: kugouSongHash);
    final krcText = answer.data["lyric"];
    if (krcText is String) {
      return Krc.fromKrcText(krcText);
    }
  } catch (err, trace) {
    LOGGER.e(err, stackTrace: trace);
  }

  return null;
}

Future<Lyric?> getOnlineLyric({
  int? qqSongId,
  String? kugouSongHash,
  String? neteaseSongId,
}) async {
  Lyric? lyric;
  if (qqSongId != null) {
    lyric = (await _getQQSyncLyric(qqSongId));
  } else if (kugouSongHash != null) {
    lyric = (await _getKugouSyncLyric(kugouSongHash));
  } else if (neteaseSongId != null) {
    lyric = await _getNeteaseUnsyncLyric(neteaseSongId);
  }
  return lyric;
}

Future<Lyric?> getMostMatchedLyric(Audio audio) async {
  final unisearchResult = await uniSearch(audio);
  if (unisearchResult.isEmpty) return null;

  final mostMatch = unisearchResult.first;

  return switch (mostMatch.source) {
    ResultSource.qq => getOnlineLyric(qqSongId: mostMatch.qqSongId),
    ResultSource.kugou =>
      getOnlineLyric(kugouSongHash: mostMatch.kugouSongHash),
    ResultSource.netease =>
      getOnlineLyric(neteaseSongId: mostMatch.neteaseSongId),
  };
}
