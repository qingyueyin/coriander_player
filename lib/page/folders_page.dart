import 'package:coriander_player/utils.dart';
import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/page/page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:coriander_player/app_paths.dart' as app_paths;

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  late final List<AudioFolder> _folders =
      List<AudioFolder>.from(AudioLibrary.instance.folders);

  @override
  Widget build(BuildContext context) {
    final tree = _FolderNode.root();
    for (final f in _folders) {
      tree.insert(f);
    }

    return PageScaffold(
      title: "文件夹",
      subtitle: "${_folders.length} 个文件夹",
      actions: const [],
      body: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: tree.sortedChildren
              .map((n) => _FolderTreeTile(node: n, depth: 0))
              .toList(),
        ),
      ),
    );
  }
}

class _FolderNode {
  final String name;
  final Map<String, _FolderNode> children = {};
  AudioFolder? folder;

  _FolderNode(this.name);
  factory _FolderNode.root() => _FolderNode("__root__");

  List<_FolderNode> get sortedChildren {
    final list = children.values.toList();
    list.sort((a, b) => a.name.naturalCompareTo(b.name));
    return list;
  }

  void insert(AudioFolder folder) {
    final segments = folder.path
        .split(RegExp(r"[\\/]+"))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    var node = this;
    for (final seg in segments) {
      node = node.children.putIfAbsent(seg, () => _FolderNode(seg));
    }
    node.folder = folder;
  }
}

class _FolderTreeTile extends StatelessWidget {
  const _FolderTreeTile({required this.node, required this.depth});

  final _FolderNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final folder = node.folder;
    final hasChildren = node.children.isNotEmpty;

    if (!hasChildren) {
      return ListTile(
        title: Text(node.name, softWrap: false, maxLines: 1),
        subtitle: folder == null
            ? null
            : Text(
                "修改日期：${DateTime.fromMillisecondsSinceEpoch(folder.modified * 1000)}",
                softWrap: false,
                maxLines: 1,
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        onTap: folder == null
            ? null
            : () => context.push(app_paths.FOLDER_DETAIL_PAGE, extra: folder),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        collapsedIconColor: scheme.onSurface.withOpacity(0.7),
        iconColor: scheme.onSurface.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        title: Text(node.name, softWrap: false, maxLines: 1),
        children: [
          if (folder != null)
            Padding(
              padding: EdgeInsets.only(left: 16.0 + (depth + 1) * 8.0),
              child: ListTile(
                dense: true,
                title: const Text("打开"),
                leading: Icon(Symbols.folder_open),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onTap: () => context.push(
                  app_paths.FOLDER_DETAIL_PAGE,
                  extra: folder,
                ),
              ),
            ),
          ...node.sortedChildren.map(
            (c) => Padding(
              padding: EdgeInsets.only(left: 16.0 + (depth + 1) * 8.0),
              child: _FolderTreeTile(node: c, depth: depth + 1),
            ),
          ),
        ],
      ),
    );
  }
}
