import 'dart:async';

import 'package:coriander_player/component/album_tile.dart';
import 'package:coriander_player/component/artist_tile.dart';
import 'package:coriander_player/component/audio_tile.dart';
import 'package:coriander_player/hotkeys_helper.dart';
import 'package:coriander_player/library/playlist.dart';
import 'package:coriander_player/library/union_search_result.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

final SEARCH_BAR_KEY = GlobalKey();

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _searchController = TextEditingController();
  late final ValueNotifier<UnionSearchResult> _result = ValueNotifier(
    UnionSearchResult(''),
  );
  late final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _result.dispose();
    _isSearching.dispose();
    super.dispose();
  }

  Widget _sectionHeader(ColorScheme scheme, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Focus(
              onFocusChange: HotkeysHelper.onFocusChanges,
              child: Hero(
                tag: SEARCH_BAR_KEY,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Symbols.search),
                    hintText: "搜索歌曲、艺术家、专辑",
                    border: const OutlineInputBorder(),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        final hasText = value.text.trim().isNotEmpty;
                        if (!hasText) return const SizedBox.shrink();
                        return IconButton(
                          tooltip: "清除",
                          onPressed: () {
                            _debounce?.cancel();
                            _searchController.clear();
                            _result.value = UnionSearchResult('');
                            _isSearching.value = false;
                          },
                          icon: const Icon(Symbols.close),
                        );
                      },
                    ),
                  ),
                  onChanged: (text) {
                    final query = text.trim();
                    _debounce?.cancel();
                    if (query.isEmpty) {
                      _result.value = UnionSearchResult('');
                      _isSearching.value = false;
                      return;
                    }

                    _isSearching.value = true;
                    _debounce = Timer(const Duration(milliseconds: 450), () {
                      if (!mounted) return;
                      _result.value = UnionSearchResult.search(query);
                      _isSearching.value = false;
                    });
                  },
                  onSubmitted: (_) {},
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _isSearching,
              builder: (context, searching, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: searching
                    ? const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: LinearProgressIndicator(minHeight: 2.0),
                      )
                    : const SizedBox(height: 12.0),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _result,
                builder: (context, value, _) {
                  final query = value.query.trim();
                  if (query.isEmpty) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Symbols.search,
                                size: 48, color: scheme.outline),
                            const SizedBox(height: 12),
                            Text(
                              "输入关键词开始搜索",
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "支持搜索歌曲、艺术家、专辑。",
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final slivers = <Widget>[];
                  if (value.audios.isNotEmpty) {
                    slivers.add(
                      SliverToBoxAdapter(
                        child: _sectionHeader(
                          scheme,
                          "音乐",
                          subtitle: "${value.audios.length} 首",
                        ),
                      ),
                    );
                    slivers.add(
                      SliverList.builder(
                        itemCount: value.audios.length,
                        itemBuilder: (context, i) {
                          final audio = value.audios[i];
                          return AudioTile(
                            audioIndex: i,
                            playlist: value.audios,
                            action: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: "下一首播放",
                                  onPressed: () {
                                    PlayService.instance.playbackService
                                        .addToNext(audio);
                                  },
                                  icon: const Icon(Symbols.plus_one),
                                ),
                                MenuAnchor(
                                  consumeOutsideTap: true,
                                  menuChildren: List.generate(
                                    PLAYLISTS.length,
                                    (playlistIndex) {
                                      final playlist = PLAYLISTS[playlistIndex];
                                      return MenuItemButton(
                                        onPressed: () {
                                          final added =
                                              playlist.audios.containsKey(audio.path);
                                          if (added) {
                                            showTextOnSnackBar(
                                              "歌曲“${audio.title}”已存在",
                                            );
                                            return;
                                          }
                                          playlist.audios[audio.path] = audio;
                                          showTextOnSnackBar(
                                            "成功将“${audio.title}”添加到歌单“${playlist.name}”",
                                          );
                                        },
                                        leadingIcon:
                                            const Icon(Symbols.queue_music),
                                        child: Text(playlist.name),
                                      );
                                    },
                                  ),
                                  builder: (context, controller, _) {
                                    return IconButton(
                                      tooltip: "添加到歌单",
                                      onPressed: () {
                                        if (PLAYLISTS.isEmpty) {
                                          showTextOnSnackBar("还未创建任何歌单");
                                          return;
                                        }
                                        if (controller.isOpen) {
                                          controller.close();
                                        } else {
                                          controller.open();
                                        }
                                      },
                                      icon: const Icon(Symbols.queue_music),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }

                  if (value.artists.isNotEmpty) {
                    slivers.add(
                      SliverToBoxAdapter(
                        child: _sectionHeader(
                          scheme,
                          "艺术家",
                          subtitle: "${value.artists.length} 位",
                        ),
                      ),
                    );
                    slivers.add(
                      SliverList.builder(
                        itemCount: value.artists.length,
                        itemBuilder: (context, i) => ArtistTile(
                          artist: value.artists[i],
                        ),
                      ),
                    );
                  }

                  if (value.album.isNotEmpty) {
                    slivers.add(
                      SliverToBoxAdapter(
                        child: _sectionHeader(
                          scheme,
                          "专辑",
                          subtitle: "${value.album.length} 张",
                        ),
                      ),
                    );
                    slivers.add(
                      SliverList.builder(
                        itemCount: value.album.length,
                        itemBuilder: (context, i) => AlbumTile(
                          album: value.album[i],
                        ),
                      ),
                    );
                  }

                  if (slivers.isEmpty) {
                    return Center(
                      child: Text(
                        "没有找到相关结果",
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    );
                  }

                  slivers.add(
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 96.0),
                    ),
                  );
                  return CustomScrollView(slivers: slivers);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
