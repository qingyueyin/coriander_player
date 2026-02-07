// ignore_for_file: camel_case_types

import 'dart:ui';

import 'package:coriander_player/app_preference.dart';
import 'package:coriander_player/component/motion.dart';
import 'package:coriander_player/component/responsive_builder.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class DestinationDesc {
  final IconData icon;
  final String label;
  final String desPath;
  DestinationDesc(this.icon, this.label, this.desPath);
}

final destinations = <DestinationDesc>[
  DestinationDesc(Symbols.library_music, "音乐", app_paths.AUDIOS_PAGE),
  DestinationDesc(Symbols.artist, "艺术家", app_paths.ARTISTS_PAGE),
  DestinationDesc(Symbols.album, "专辑", app_paths.ALBUMS_PAGE),
  DestinationDesc(Symbols.folder, "文件夹", app_paths.FOLDERS_PAGE),
  DestinationDesc(Symbols.list, "歌单", app_paths.PLAYLISTS_PAGE),
  DestinationDesc(Symbols.settings, "设置", app_paths.SETTINGS_PAGE),
];

class SideNav extends StatefulWidget {
  const SideNav({super.key});

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  final sidebarExpanded = ValueNotifier(AppPreference.instance.sidebarExpanded);
  static const double _collapsedWidth = 80.0;
  static const double _expandedWidth = 240.0;
  static const double _iconSize = 24.0;
  static const double _itemHeight = 54.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.toString();
    final matchedIndex = destinations.indexWhere(
      (desc) => location.startsWith(desc.desPath),
    );
    final int? selectedIndex = matchedIndex == -1 ? null : matchedIndex;

    void onDestinationSelected(int value) {
      if (selectedIndex == value) return;

      final index = app_paths.START_PAGES.indexOf(destinations[value].desPath);
      if (index != -1) AppPreference.instance.startPage = index;

      context.go(destinations[value].desPath);

      var scaffold = Scaffold.of(context);
      if (scaffold.hasDrawer) scaffold.closeDrawer();
    }

    void toggleSidebar() {
      final newVal = !sidebarExpanded.value;
      sidebarExpanded.value = newVal;
      AppPreference.instance.sidebarExpanded = newVal;
      AppPreference.instance.save();
    }

    return ResponsiveBuilder(
      builder: (context, screenType) {
        switch (screenType) {
          case ScreenType.small:
            return NavigationDrawer(
              backgroundColor: scheme.surfaceContainer,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              children: List.generate(
                destinations.length,
                (i) => NavigationDrawerDestination(
                  icon: Icon(destinations[i].icon),
                  label: Text(destinations[i].label),
                ),
              ),
            );
          case ScreenType.medium:
            return NavigationRail(
              backgroundColor: scheme.surfaceContainer,
              minWidth: 80.0,
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: List.generate(
                destinations.length,
                (i) => NavigationRailDestination(
                  icon: Icon(destinations[i].icon),
                  label: Text(destinations[i].label),
                ),
              ),
            );
          case ScreenType.large:
            return ValueListenableBuilder(
              valueListenable: sidebarExpanded,
              builder: (context, expanded, _) {
                return _SmoothLargeSideNav(
                  expanded: expanded,
                  colorScheme: scheme,
                  selectedIndex: selectedIndex,
                  onToggle: toggleSidebar,
                  onSelect: onDestinationSelected,
                );
              },
            );
        }
      },
    );
  }
}

class _SmoothLargeSideNav extends StatelessWidget {
  const _SmoothLargeSideNav({
    required this.expanded,
    required this.colorScheme,
    required this.selectedIndex,
    required this.onToggle,
    required this.onSelect,
  });

  final bool expanded;
  final ColorScheme colorScheme;
  final int? selectedIndex;
  final VoidCallback onToggle;
  final void Function(int) onSelect;

  static const double _collapsedWidth = _SideNavState._collapsedWidth;
  static const double _expandedWidth = _SideNavState._expandedWidth;
  static const double _iconSize = _SideNavState._iconSize;
  static const double _itemHeight = _SideNavState._itemHeight;

  @override
  Widget build(BuildContext context) {
    final iconLeft = (_collapsedWidth - _iconSize) / 2;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        duration: MotionDuration.medium,
        curve: MotionCurve.emphasized,
        tween: Tween(begin: 0.0, end: expanded ? 1.0 : 0.0),
        builder: (context, t, _) {
          final visibleWidth = (lerpDouble(_collapsedWidth, _expandedWidth, t) ??
                  _collapsedWidth)
              .clamp(_collapsedWidth, _expandedWidth);
          return SizedBox(
            width: visibleWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colorScheme.surfaceContainer),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: _expandedWidth,
                  maxWidth: _expandedWidth,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      _NavItem(
                        height: _itemHeight,
                        iconLeft: iconLeft,
                        icon: expanded ? Symbols.menu_open : Symbols.menu,
                        label: "侧边栏",
                        expandedT: t,
                        selected: false,
                        onTap: onToggle,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: destinations.length,
                          itemBuilder: (context, i) {
                            final selected = selectedIndex == i;
                            return _NavItem(
                              height: _itemHeight,
                              iconLeft: iconLeft,
                              icon: destinations[i].icon,
                              label: destinations[i].label,
                              expandedT: t,
                              selected: selected,
                              onTap: () {
                                onSelect(i);
                                final scaffold = Scaffold.of(context);
                                if (scaffold.hasDrawer) scaffold.closeDrawer();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.height,
    required this.iconLeft,
    required this.icon,
    required this.label,
    required this.expandedT,
    required this.selected,
    required this.onTap,
  });

  final double height;
  final double iconLeft;
  final IconData icon;
  final String label;
  final double expandedT;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.secondaryContainer.withValues(alpha: 0.85)
        : Colors.transparent;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final textOpacity = expandedT.clamp(0.0, 1.0);
    final dx = lerpDouble(-12, 0, expandedT) ?? 0.0;
    const hPad = 10.0;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: iconLeft - hPad,
                  child: Icon(icon, size: 24, color: fg.withValues(alpha: 0.90)),
                ),
                Positioned(
                  left: 56,
                  right: 12,
                  child: IgnorePointer(
                    ignoring: expandedT < 0.98,
                    child: Opacity(
                      opacity: textOpacity,
                      child: Transform.translate(
                        offset: Offset(dx, 0),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: TextStyle(
                            color: fg,
                            fontSize: 14.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
