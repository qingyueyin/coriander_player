import 'dart:ui';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/enums.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/play_service/play_service.dart';
import 'package:coriander_player/page/uni_page_components.dart';
import 'package:coriander_player/page/page_scaffold.dart';
import 'package:coriander_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

typedef ContentBuilder<T> = Widget Function(BuildContext context, T item,
    int index, MultiSelectController<T>? multiSelectController);

typedef SortMethod<T> = void Function(List<T> list, SortOrder order);

class SortMethodDesc<T> {
  IconData icon;
  String name;
  SortMethod<T> method;

  SortMethodDesc({
    required this.icon,
    required this.name,
    required this.method,
  });
}

const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 300,
  mainAxisExtent: 64,
  mainAxisSpacing: 8.0,
  crossAxisSpacing: 8.0,
);

class MultiSelectController<T> extends ChangeNotifier {
  final Set<T> selected = {};
  bool enableMultiSelectView = false;

  void useMultiSelectView(bool multiSelectView) {
    enableMultiSelectView = multiSelectView;
    notifyListeners();
  }

  void select(T item) {
    selected.add(item);
    notifyListeners();
  }

  void unselect(T item) {
    selected.remove(item);
    notifyListeners();
  }

  void clear() {
    selected.clear();
    notifyListeners();
  }

  void selectAll(Iterable<T> items) {
    selected.addAll(items);
    notifyListeners();
  }
}

/// `AudiosPage`, `ArtistsPage`, `AlbumsPage`, `FoldersPage`, `FolderDetailPage` 页面的主要组件，
/// 提供随机播放以及更改排序方式、排序顺序、内容视图的支持。
///
/// `enableShufflePlay` 只能在 `T` 是 `Audio` 时为 `ture`
///
/// `enableSortMethod` 为 `true` 时，`sortMethods` 不可为空且必须包含一个 `SortMethodDesc`
///
/// `defaultContentView` 表示默认的内容视图。如果设置为 `ContentView.list`，就以单行列表视图展示内容；
/// 如果是 `ContentView.table`，就以最大 300 * 64 的子组件以 8 为间距组成的表格展示内容。
///
/// `multiSelectController` 可以使页面进入多选状态。如果它不为空，则 `multiSelectViewActions` 也不可为空
class UniPage<T> extends StatefulWidget {
  const UniPage({
    super.key,
    required this.pref,
    required this.title,
    this.subtitle,
    required this.contentList,
    required this.contentBuilder,
    this.primaryAction,
    required this.enableShufflePlay,
    required this.enableSortMethod,
    required this.enableSortOrder,
    required this.enableContentViewSwitch,
    this.sortMethods,
    this.locateTo,
    this.multiSelectController,
    this.multiSelectViewActions,
  });

  final PagePreference pref;

  final String title;
  final String? subtitle;

  final List<T> contentList;
  final ContentBuilder<T> contentBuilder;

  final Widget? primaryAction;

  final bool enableShufflePlay;
  final bool enableSortMethod;
  final bool enableSortOrder;
  final bool enableContentViewSwitch;

  final List<SortMethodDesc<T>>? sortMethods;

  final T? locateTo;

  final MultiSelectController<T>? multiSelectController;
  final List<Widget>? multiSelectViewActions;

  @override
  State<UniPage<T>> createState() => _UniPageState<T>();
}

class _UniPageState<T> extends State<UniPage<T>> {
  late SortMethodDesc<T>? currSortMethod =
      widget.sortMethods?[widget.pref.sortMethod];
  late SortOrder currSortOrder = widget.pref.sortOrder;
  late ContentView currContentView = widget.pref.contentView;
  late ScrollController scrollController = ScrollController();
  String? _activeIndexKey;

  static const List<String> _alphaKeys = [
    "#",
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
  ];

  String? _indexTextForItem(Object item) {
    if (item is Audio) return item.title;
    if (item is Artist) return item.name;
    if (item is Album) return item.name;
    if (item is AudioFolder) return item.path;
    return null;
  }

  Map<String, int> _buildAlphaIndexMap() {
    if (widget.contentList.length < 30) return const {};
    final map = <String, int>{};
    for (int i = 0; i < widget.contentList.length; i++) {
      final item = widget.contentList[i];
      final text = _indexTextForItem(item as Object);
      if (text == null) continue;
      final key = text.getIndexKey();
      map.putIfAbsent(key, () => i);
    }
    return map;
  }

  int? _findNearestIndexKeyTarget(String key, Map<String, int> indexMap) {
    if (indexMap.isEmpty) return null;
    final direct = indexMap[key];
    if (direct != null) return direct;
    final startAt = _alphaKeys.indexOf(key);
    if (startAt < 0) return null;
    for (int i = startAt + 1; i < _alphaKeys.length; i++) {
      final v = indexMap[_alphaKeys[i]];
      if (v != null) return v;
    }
    if (key == "#") return indexMap.values.reduce((a, b) => a < b ? a : b);
    return null;
  }

  Widget _alphaIndexBar() {
    if (currContentView != ContentView.list) return const SizedBox.shrink();
    final indexMap = _buildAlphaIndexMap();
    if (indexMap.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 4.0,
      top: 8.0,
      bottom: 104.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void handleDy(double dy) {
            final h = constraints.maxHeight;
            if (h <= 0) return;
            final t = (dy / h).clamp(0.0, 0.999999);
            final idx =
                (t * _alphaKeys.length).floor().clamp(0, _alphaKeys.length - 1);
            final key = _alphaKeys[idx];
            final targetAt = _findNearestIndexKeyTarget(key, indexMap);
            if (targetAt == null) return;
            setState(() => _activeIndexKey = key);
            _scrollToIndex(targetAt);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => handleDy(d.localPosition.dy),
            onVerticalDragDown: (d) => handleDy(d.localPosition.dy),
            onVerticalDragUpdate: (d) => handleDy(d.localPosition.dy),
            onVerticalDragEnd: (_) => setState(() => _activeIndexKey = null),
            onVerticalDragCancel: () => setState(() => _activeIndexKey = null),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _alphaKeys
                  .map(
                    (k) => SizedBox(
                      height: constraints.maxHeight / _alphaKeys.length,
                      child: Center(
                        child: Text(
                          k,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _activeIndexKey == k
                                ? Theme.of(context).colorScheme.primary
                                : (indexMap.containsKey(k)
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.85)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.25)),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  void _scrollToIndex(int targetAt) {
    if (targetAt < 0 || targetAt >= widget.contentList.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;

      if (currContentView == ContentView.list) {
        scrollController.animateTo(
          targetAt * 64.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
        );
      } else {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox) {
          final ratio =
              PlatformDispatcher.instance.views.first.devicePixelRatio;
          final width = renderObject.size.width - 32;
          final crossAxisCount = (width * ratio / 300).floor().clamp(1, 100);
          final offset = (targetAt ~/ crossAxisCount) * (64.0 + 8.0);
          scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
          );
        }
      }
    });
  }

  Widget _locateNowPlayingButton() {
    if (widget.contentList is! List<Audio>) return const SizedBox.shrink();
    final playbackService = PlayService.instance.playbackService;

    return ListenableBuilder(
      listenable: playbackService,
      builder: (context, _) {
        final nowPlaying = playbackService.nowPlaying;
        if (nowPlaying == null) return const SizedBox.shrink();

        final contentList = widget.contentList as List<Audio>;
        final targetAt =
            contentList.indexWhere((audio) => audio.path == nowPlaying.path);
        if (targetAt < 0) return const SizedBox.shrink();

        return ResponsiveBuilder(
          builder: (context, screenType) {
            final bottom = screenType == ScreenType.small ? 88.0 : 112.0;
            final right = screenType == ScreenType.small ? 88.0 : 128.0;
            return Positioned(
              right: right,
              bottom: bottom,
              child: IconButton.filledTonal(
                tooltip: "定位正在播放",
                onPressed: () => _scrollToIndex(targetAt),
                icon: const Icon(Symbols.my_location),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    currSortMethod?.method(widget.contentList, currSortOrder);
    if (widget.locateTo == null) return;

    int targetAt = widget.contentList.indexOf(widget.locateTo as T);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      if (currContentView == ContentView.list) {
        scrollController.jumpTo(targetAt * 64);
      } else {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox) {
          final ratio =
              PlatformDispatcher.instance.views.first.devicePixelRatio;
          final width = renderObject.size.width - 32;
          final crossAxisCount = (width * ratio / 300).floor().clamp(1, 100);
          final offset = (targetAt ~/ crossAxisCount) * (64.0 + 8.0);
          scrollController.jumpTo(offset);
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant UniPage<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    currSortMethod?.method(widget.contentList, currSortOrder);
  }

  void setSortMethod(SortMethodDesc<T> sortMethod) {
    setState(() {
      currSortMethod = sortMethod;
      widget.pref.sortMethod = widget.sortMethods?.indexOf(sortMethod) ?? 0;
      currSortMethod?.method(widget.contentList, currSortOrder);
    });
  }

  void setSortOrder(SortOrder sortOrder) {
    setState(() {
      currSortOrder = sortOrder;
      widget.pref.sortOrder = sortOrder;
      currSortMethod?.method(widget.contentList, currSortOrder);
    });
  }

  void setContentView(ContentView contentView) {
    setState(() {
      currContentView = contentView;
      widget.pref.contentView = contentView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];
    if (widget.primaryAction != null) {
      actions.add(widget.primaryAction!);
    }
    if (widget.enableShufflePlay) {
      actions.add(ShufflePlay<T>(contentList: widget.contentList));
    }
    if (widget.enableSortMethod) {
      actions.add(SortMethodComboBox<T>(
        sortMethods: widget.sortMethods!,
        contentList: widget.contentList,
        currSortMethod: currSortMethod!,
        setSortMethod: setSortMethod,
      ));
    }
    if (widget.enableSortOrder) {
      actions.add(SortOrderSwitch<T>(
        sortOrder: currSortOrder,
        setSortOrder: setSortOrder,
      ));
    }
    if (widget.enableContentViewSwitch) {
      actions.add(ContentViewSwitch<T>(
        contentView: currContentView,
        setContentView: setContentView,
      ));
    }

    return widget.multiSelectController == null
        ? result(null, actions)
        : ListenableBuilder(
            listenable: widget.multiSelectController!,
            builder: (context, _) => result(
              widget.multiSelectController!,
              actions,
            ),
          );
  }

  Widget result(
      MultiSelectController<T>? multiSelectController, List<Widget> actions) {
    return PageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: multiSelectController == null
          ? actions
          : multiSelectController.enableMultiSelectView
              ? widget.multiSelectViewActions!
              : actions,
      body: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            switch (currContentView) {
              ContentView.list => ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 96.0),
                  itemCount: widget.contentList.length,
                  itemExtent: 64,
                  itemBuilder: (context, i) => widget.contentBuilder(
                    context,
                    widget.contentList[i],
                    i,
                    multiSelectController,
                  ),
                ),
              ContentView.table => GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 96.0),
                  gridDelegate: gridDelegate,
                  itemCount: widget.contentList.length,
                  itemBuilder: (context, i) => widget.contentBuilder(
                    context,
                    widget.contentList[i],
                    i,
                    multiSelectController,
                  ),
                ),
            },
            _locateNowPlayingButton(),
            _alphaIndexBar(),
          ],
        ),
      ),
    );
  }
}
