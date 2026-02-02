part of 'page.dart';

class _NowPlayingPage_Immersive extends StatelessWidget {
  const _NowPlayingPage_Immersive();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isWide = screenSize.width >= 920;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
      child: Column(
        children: [
          Expanded(
            child: isWide
                ? const Row(
                    children: [
                      Expanded(child: _ImmersiveLeftPanel()),
                      SizedBox(width: 24.0),
                      Expanded(
                        child: VerticalLyricView(
                          showControls: false,
                          enableSeekOnTap: false,
                          centerVertically: false,
                        ),
                      ),
                    ],
                  )
                : const Column(
                    children: [
                      Expanded(child: _ImmersiveLeftPanel()),
                      SizedBox(height: 16.0),
                      Expanded(
                        child: VerticalLyricView(
                          showControls: false,
                          enableSeekOnTap: false,
                          centerVertically: false,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveLeftPanel extends StatelessWidget {
  const _ImmersiveLeftPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final edge = min(constraints.maxWidth, constraints.maxHeight);
        final coverSize = (edge * 0.48).clamp(220.0, 420.0);

        return Center(
          child: SizedBox(
            width: coverSize,
            child: ListenableBuilder(
              listenable: PlayService.instance.playbackService,
              builder: (context, _) {
                final nowPlaying =
                    PlayService.instance.playbackService.nowPlaying;
                final title = nowPlaying?.title ?? "Coriander Player";
                final subtitle = nowPlaying == null
                    ? ""
                    : "${nowPlaying.artist} · ${nowPlaying.album}";

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSecondaryContainer.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: coverSize,
                      height: coverSize,
                      child: _ImmersiveCover(size: coverSize),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: coverSize,
                      child: const _NowPlayingSlider(),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ImmersiveHelpOverlay extends StatefulWidget {
  const _ImmersiveHelpOverlay();

  @override
  State<_ImmersiveHelpOverlay> createState() => _ImmersiveHelpOverlayState();
}

class _ImmersiveHelpOverlayState extends State<_ImmersiveHelpOverlay> {
  bool _visible = false;
  Timer? _timer;

  void _bump() {
    _timer?.cancel();
    if (!_visible) {
      setState(() {
        _visible = true;
      });
    }
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _visible = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final textStyle = TextStyle(color: scheme.onSurface);
        return AlertDialog(
          title: const Text("快捷键"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Space：播放/暂停", style: textStyle),
              const SizedBox(height: 8),
              Text("Ctrl + ←：上一曲", style: textStyle),
              const SizedBox(height: 8),
              Text("Ctrl + →：下一曲", style: textStyle),
              const SizedBox(height: 8),
              Text("Ctrl + ↑：音量 +", style: textStyle),
              const SizedBox(height: 8),
              Text("Ctrl + ↓：音量 -", style: textStyle),
              const SizedBox(height: 8),
              Text("F1：进入/退出沉浸模式", style: textStyle),
              const SizedBox(height: 8),
              Text("ESC：退出沉浸并回到主界面", style: textStyle),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("关闭"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: MouseRegion(
            onHover: (_) => _bump(),
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 16,
          left: 20,
          right: 20,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            offset: _visible ? Offset.zero : const Offset(0.0, -0.25),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              opacity: _visible ? 1.0 : 0.0,
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Material(
                      color: scheme.secondaryContainer.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(14.0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        child: ListenableBuilder(
                          listenable: PlayService.instance.playbackService,
                          builder: (context, _) {
                            final nowPlaying =
                                PlayService.instance.playbackService.nowPlaying;
                            final title =
                                nowPlaying?.title ?? "Coriander Player";
                            final subtitle = nowPlaying == null
                                ? ""
                                : "${nowPlaying.artist} · ${nowPlaying.album}";
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onSecondaryContainer
                                          .withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 120,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            offset: _visible ? Offset.zero : const Offset(0.0, 0.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.fastOutSlowIn,
              opacity: _visible ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_visible,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: scheme.secondaryContainer.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 10.0,
                        ),
                        child: Text(
                          "快捷键说明",
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: scheme.secondaryContainer.withOpacity(0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _showDialog,
                        icon: Icon(
                          Symbols.help_outline,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImmersiveCover extends StatefulWidget {
  const _ImmersiveCover({required this.size});

  final double size;

  @override
  State<_ImmersiveCover> createState() => _ImmersiveCoverState();
}

class _ImmersiveCoverState extends State<_ImmersiveCover> {
  final playbackService = PlayService.instance.playbackService;
  Future<ImageProvider<Object>?>? _coverFuture;
  String? _coverPath;

  void _updateCover() {
    final nextPath = playbackService.nowPlaying?.path;
    if (nextPath == _coverPath) return;
    _coverPath = nextPath;
    setState(() {
      _coverFuture = playbackService.nowPlaying?.largeCover;
    });
  }

  @override
  void initState() {
    super.initState();
    playbackService.addListener(_updateCover);
    _coverFuture = playbackService.nowPlaying?.largeCover;
    _coverPath = playbackService.nowPlaying?.path;
  }

  @override
  void dispose() {
    playbackService.removeListener(_updateCover);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final placeholder = Icon(
      Symbols.broken_image,
      size: 128.0,
      color: scheme.onSecondaryContainer,
    );
    final size = widget.size;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: RepaintBoundary(
          child: _coverFuture == null
              ? Center(child: placeholder)
              : FutureBuilder(
                  future: _coverFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final image = snapshot.data;
                    if (image == null) return Center(child: placeholder);
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.fastOutSlowIn,
                      switchOutCurve: Curves.fastOutSlowIn,
                      child: ClipRRect(
                        key: ValueKey(image),
                        borderRadius: BorderRadius.circular(14.0),
                        child: Image(
                          image: image,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Center(child: placeholder),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
