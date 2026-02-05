import 'dart:convert';
import 'dart:io';
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

enum ResultSource { qq, kugou, netease, lrclib }

double _computeScore(Audio audio, String title, String artists, String album) {
  int maxScore = audio.title.length + audio.artist.length + audio.album.length;
  int score = 0;

  int minTitleLength = min(audio.title.length, title.length);
  for (int i = 0; i < minTitleLength; ++i) {
    if (audio.title[i] == title[i]) score += 1;
  }

  int minArtistLength = min(audio.artist.length, artists.length);
  for (int i = 0; i < minArtistLength; ++i) {
    if (audio.artist[i] == artists[i]) score += 1;
  }

  int minAlbumLength = min(audio.album.length, album.length);
  for (int i = 0; i < minAlbumLength; ++i) {
    if (audio.album[i] == album[i]) score += 1;
  }

  return score / maxScore;
}

class SongSearchResult {
  ResultSource source;
  String title;
  String artists;
  String album;
  double score;
  int? durationMs;

  /// for qq result
  int? qqSongId;

  /// for netease result
  String? neteaseSongId;

  /// for kugou result
  String? kugouSongHash;

  /// for lrclib result
  String? lrclibId;

  SongSearchResult(
      this.source, this.title, this.artists, this.album, this.score,
      {this.qqSongId,
      this.neteaseSongId,
      this.kugouSongHash,
      this.lrclibId,
      this.durationMs});

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

  static SongSearchResult fromLrclibSearchResult(Map info, Audio audio) {
    final title = (info["trackName"] ?? "").toString();
    final album = (info["albumName"] ?? "").toString();
    final artists = (info["artistName"] ?? "").toString();
    final durationSec = info["duration"];
    final durationMs = durationSec is num ? (durationSec * 1000).round() : null;
    final id = info["id"];
    return SongSearchResult(
      ResultSource.lrclib,
      title,
      artists,
      album,
      _computeScore(audio, title, artists, album),
      lrclibId: id?.toString(),
      durationMs: durationMs,
    );
  }
}

Future<List<SongSearchResult>> _lrclibSearchSong(Audio audio, String query) async {
  try {
    final client = HttpClient();
    final uri = Uri.https("lrclib.net", "/api/search", {"q": query});
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, "application/json");
    req.headers.set(HttpHeaders.userAgentHeader, "coriander_player");
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final decoded = json.decode(body);
    if (decoded is! List) return [];
    final out = <SongSearchResult>[];
    for (var i = 0; i < decoded.length && i < 8; i++) {
      final item = decoded[i];
      if (item is! Map) continue;
      out.add(SongSearchResult.fromLrclibSearchResult(item, audio));
    }
    client.close(force: true);
    return out;
  } catch (_) {
    return [];
  }
}

<<<<<<< HEAD
=======
Future<List<SongSearchResult>> _uniSearchOnce(Audio audio, String query) async {
  List<SongSearchResult> result = [];

  final lrclibResultList = await _lrclibSearchSong(audio, query);
  result.addAll(lrclibResultList);

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

>>>>>>> 4db0256cbef7afac08daba7f53a38cf9b4e9115b
Future<List<SongSearchResult>> uniSearch(Audio audio) async {
  final query = audio.title;
  try {
    List<SongSearchResult> result = [];

<<<<<<< HEAD
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
=======
    for (final query in queries) {
      final batch = await _uniSearchOnce(audio, query);
      for (final item in batch) {
        final key = switch (item.source) {
          ResultSource.qq => 'qq:${item.qqSongId ?? '${item.title}|${item.artists}|${item.album}'}',
          ResultSource.netease => 'netease:${item.neteaseSongId ?? '${item.title}|${item.artists}|${item.album}'}',
          ResultSource.kugou => 'kugou:${item.kugouSongHash ?? '${item.title}|${item.artists}|${item.album}'}',
          ResultSource.lrclib => 'lrclib:${item.lrclibId ?? '${item.title}|${item.artists}|${item.album}'}',
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
>>>>>>> 4db0256cbef7afac08daba7f53a38cf9b4e9115b
    }

    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  } catch (err, trace) {
    LOGGER.e("query: $query");
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

Future<Lrc?> _getLrclibLyric({
  required String trackName,
  required String artistName,
  required String albumName,
  required int durationMs,
}) async {
  try {
    final client = HttpClient();
    final uri = Uri.https("lrclib.net", "/api/get", {
      "track_name": trackName,
      "artist_name": artistName,
      "album_name": albumName,
      "duration": (durationMs / 1000.0).toString(),
    });
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.acceptHeader, "application/json");
    req.headers.set(HttpHeaders.userAgentHeader, "coriander_player");
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    final decoded = json.decode(body);
    if (decoded is! Map) return null;
    final synced = decoded["syncedLyrics"];
    if (synced is String && synced.trim().isNotEmpty) {
      return Lrc.fromLrcText(synced, LrcSource.web);
    }
  } catch (_) {}
  return null;
}

Future<Lyric?> getOnlineLyric({
  int? qqSongId,
  String? kugouSongHash,
  String? neteaseSongId,
  String? lrclibTrackName,
  String? lrclibArtistName,
  String? lrclibAlbumName,
  int? lrclibDurationMs,
  Audio? lrclibAudioFallback,
}) async {
  Lyric? lyric;
  if (qqSongId != null) {
    lyric = (await _getQQSyncLyric(qqSongId));
  } else if (kugouSongHash != null) {
    lyric = (await _getKugouSyncLyric(kugouSongHash));
  } else if (neteaseSongId != null) {
    lyric = await _getNeteaseUnsyncLyric(neteaseSongId);
  } else {
    final trackName = lrclibTrackName ?? lrclibAudioFallback?.title;
    final artistName = lrclibArtistName ?? lrclibAudioFallback?.artist;
    final albumName = lrclibAlbumName ?? lrclibAudioFallback?.album;
    final durationMs =
        lrclibDurationMs ?? ((lrclibAudioFallback?.duration ?? 0) * 1000);
    if (trackName != null &&
        artistName != null &&
        albumName != null &&
        durationMs > 0) {
      lyric = await _getLrclibLyric(
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        durationMs: durationMs,
      );
    }
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
    ResultSource.lrclib => getOnlineLyric(
        lrclibTrackName: mostMatch.title,
        lrclibArtistName: mostMatch.artists,
        lrclibAlbumName: mostMatch.album,
        lrclibDurationMs: mostMatch.durationMs ?? audio.duration * 1000,
        lrclibAudioFallback: audio,
      ),
  };
}
