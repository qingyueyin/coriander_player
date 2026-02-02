import 'package:coriander_player/library/audio_library.dart';
import 'package:coriander_player/component/motion.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:coriander_player/app_paths.dart' as app_paths;

class ArtistTile extends StatefulWidget {
  const ArtistTile({
    super.key,
    required this.artist,
  });

  final Artist artist;

  @override
  State<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends State<ArtistTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Icon(
      Symbols.broken_image,
      color: scheme.onSurface,
      size: 48,
    );
    return Tooltip(
      message: widget.artist.name,
      child: AnimatedContainer(
        duration: MotionDuration.fast,
        curve: MotionCurve.standard,
        decoration: BoxDecoration(
          color: _hovered ? scheme.primary.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: InkWell(
          onHover: (v) => setState(() => _hovered = v),
          onTap: () => context.push(
            app_paths.ARTIST_DETAIL_PAGE,
            extra: widget.artist,
          ),
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                FutureBuilder(
                  future: widget.artist.works.first.cover,
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return placeholder;
                    }
                    return ClipOval(
                      child: Image(
                        image: snapshot.data!,
                        width: 48.0,
                        height: 48.0,
                        errorBuilder: (_, __, ___) => placeholder,
                      ),
                    );
                  },
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      widget.artist.name,
                      softWrap: false,
                      maxLines: 2,
                      style: TextStyle(color: scheme.onSurface),
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
