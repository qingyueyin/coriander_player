// ignore_for_file: camel_case_types

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

      context.push(destinations[value].desPath);

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
                final Widget child = expanded
                    ? SizedBox(
                        key: const ValueKey("sidebar_drawer"),
                        width: 240.0,
                        child: NavigationDrawer(
                          backgroundColor: scheme.surfaceContainer,
                          selectedIndex:
                              selectedIndex == null ? null : selectedIndex + 1,
                          onDestinationSelected: (value) {
                            if (value == 0) {
                              toggleSidebar();
                              return;
                            }
                            onDestinationSelected(value - 1);
                          },
                          children: [
                            const NavigationDrawerDestination(
                              icon: Icon(Symbols.menu_open),
                              label: Text("收起侧边栏"),
                            ),
                            ...List.generate(
                              destinations.length,
                              (i) => NavigationDrawerDestination(
                                icon: Icon(destinations[i].icon),
                                label: Text(destinations[i].label),
                              ),
                            )
                          ],
                        ),
                      )
                    : SizedBox(
                        key: const ValueKey("sidebar_rail"),
                        width: 80.0,
                        child: NavigationRail(
                          backgroundColor: scheme.surfaceContainer,
                          minWidth: 80.0,
                          selectedIndex:
                              selectedIndex == null ? null : selectedIndex + 1,
                          onDestinationSelected: (value) {
                            if (value == 0) {
                              toggleSidebar();
                              return;
                            }
                            onDestinationSelected(value - 1);
                          },
                          extended: false,
                          destinations: List.generate(
                            destinations.length + 1,
                            (i) => i == 0
                                ? const NavigationRailDestination(
                                    icon: Icon(Symbols.menu),
                                    label: Text("展开"),
                                  )
                                : NavigationRailDestination(
                                    icon: Icon(destinations[i - 1].icon),
                                    label: Text(destinations[i - 1].label),
                                  ),
                          ),
                        ),
                      );

                return ClipRect(
                  child: AnimatedSize(
                    duration: MotionDuration.slow,
                    curve: MotionCurve.standard,
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: MotionDuration.base,
                      switchInCurve: MotionCurve.standard,
                      switchOutCurve: MotionCurve.standard,
                      transitionBuilder: (child, animation) {
                        final offsetAnimation =
                            Tween(begin: const Offset(0.06, 0.0), end: Offset.zero)
                                .animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: offsetAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: child,
                    ),
                  ),
                );
              },
            );
        }
      },
    );
  }
}
