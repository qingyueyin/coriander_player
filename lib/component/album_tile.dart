import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/component/motion.dart';
import 'package:coriander_player/page/uni_page.dart';
import 'package:coriander_player/theme_provider.dart';
import 'package:coriander_player/enums.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;

class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    this.multiSelectController,
    this.view = ContentView.list,
  });

  final Album album;
  final MultiSelectController<Album>? multiSelectController;
  final ContentView view;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final menuStyle = MenuStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeProvider.radiusLarge)),
      ),
    );
    final menuItemStyle = ButtonStyle(
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeProvider.radiusMedium)),
      ),
    );
    final placeholder = Icon(
      Symbols.broken_image,
      size: 48,
      color: scheme.onSurface,
    );
    final isSelected =
        widget.multiSelectController?.selected.contains(widget.album) == true;
    final isMultiSelectView =
        widget.multiSelectController?.enableMultiSelectView == true;
    return Tooltip(
      message: widget.album.name,
      child: MenuTheme(
        data: MenuThemeData(style: menuStyle),
        child: MenuAnchor(
          consumeOutsideTap: true,
          style: menuStyle,
          menuChildren: [
            MenuItemButton(
              style: menuItemStyle,
              onPressed: () => context.push(
                app_paths.ALBUM_DETAIL_PAGE,
                extra: widget.album,
              ),
              leadingIcon: const Icon(Symbols.open_in_new),
              child: const Text("打开"),
            ),
            if (widget.multiSelectController != null)
              MenuItemButton(
                style: menuItemStyle,
                onPressed: () {
                  widget.multiSelectController!.useMultiSelectView(true);
                  widget.multiSelectController!.select(widget.album);
                },
                leadingIcon: const Icon(Symbols.select),
                child: const Text("多选"),
              ),
          ],
          builder: (context, controller, _) => AnimatedContainer(
            duration: MotionDuration.fast,
            curve: MotionCurve.standard,
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.secondaryContainer
                  : _hovered
                      ? scheme.primary.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(ThemeProvider.radiusMedium),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onHover: (v) => setState(() => _hovered = v),
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                    return;
                  }

                  if (!isMultiSelectView) {
                    context.push(
                      app_paths.ALBUM_DETAIL_PAGE,
                      extra: widget.album,
                    );
                    return;
                  }

                  if (isSelected) {
                    widget.multiSelectController?.unselect(widget.album);
                  } else {
                    widget.multiSelectController?.select(widget.album);
                  }
                },
                onLongPress: () {
                  if (widget.multiSelectController == null) return;
                  if (isMultiSelectView) return;
                  widget.multiSelectController!.useMultiSelectView(true);
                  widget.multiSelectController!.select(widget.album);
                },
                onSecondaryTapDown: (details) {
                  if (isMultiSelectView) return;
                  controller.open(
                    position: details.localPosition.translate(0, -140),
                  );
                },
                borderRadius: BorderRadius.circular(ThemeProvider.radiusMedium),
                child: widget.view == ContentView.list
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            FutureBuilder(
                              future: widget.album.works.first.cover,
                              builder: (context, snapshot) {
                                if (snapshot.data == null) {
                                  return placeholder;
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      ThemeProvider.radiusMedium),
                                  child: Image(
                                    image: snapshot.data!,
                                    width: 48.0,
                                    height: 48.0,
                                    errorBuilder: (_, __, ___) => placeholder,
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Text(
                                  widget.album.name,
                                  softWrap: false,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: scheme.onSurface),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: FutureBuilder(
                                future: widget.album.works.first.mediumCover,
                                builder: (context, snapshot) {
                                  if (snapshot.data == null) {
                                    return placeholder;
                                  }
                                  return FutureBuilder(
                                    future: ColorScheme.fromImageProvider(
                                      provider: snapshot.data!,
                                    ),
                                    builder: (context, schemeSnapshot) {
                                      final cardColor = schemeSnapshot
                                              .data?.surfaceContainer ??
                                          Colors.transparent;
                                      return DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              ThemeProvider.radiusMedium),
                                          color: cardColor,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                              ThemeProvider.radiusMedium),
                                          child: Image(
                                            image: snapshot.data!,
                                            errorBuilder: (_, __, ___) =>
                                                placeholder,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder(
                                  future: widget.album.works.first.mediumCover,
                                  builder: (context, snapshot) {
                                    if (snapshot.data == null) {
                                      return Text(
                                        widget.album.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }
                                    return FutureBuilder(
                                      future: ColorScheme.fromImageProvider(
                                        provider: snapshot.data!,
                                      ),
                                      builder: (context, schemeSnapshot) {
                                        final textColor =
                                            schemeSnapshot.data?.primary ??
                                                scheme.onSurface;
                                        return Text(
                                          widget.album.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                Text(
                                  "${widget.album.works.length} 首作品",
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
