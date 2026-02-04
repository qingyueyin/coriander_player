// ignore_for_file: camel_case_types

import 'package:coriander_player/app_preference.dart';
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
                if (expanded) {
                  return NavigationDrawer(
                    backgroundColor: scheme.surfaceContainer,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: toggleSidebar,
                              icon: const Icon(Symbols.menu_open),
                              tooltip: "收起侧边栏",
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      ...List.generate(
                        destinations.length,
                        (i) => NavigationDrawerDestination(
                          icon: Icon(destinations[i].icon),
                          label: Text(destinations[i].label),
                        ),
                      ),
                    ],
                  );
                } else {
                  return NavigationRail(
                    backgroundColor: scheme.surfaceContainer,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    extended: false,
                    leading: IconButton(
                      onPressed: toggleSidebar,
                      icon: const Icon(Symbols.menu),
                      tooltip: "展开侧边栏",
                    ),
                    destinations: List.generate(
                      destinations.length,
                      (i) => NavigationRailDestination(
                        icon: Icon(destinations[i].icon),
                        label: Text(destinations[i].label),
                      ),
                    ),
                  );
                }
              },
            );
        }
      },
    );
  }
}
