import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';

/// Playlist cover: one vinyl for an empty playlist, otherwise a 2×2 grid of
/// small vinyls labelled with the artwork of the first four songs.
class PlaylistCollage extends StatefulWidget {
  const PlaylistCollage({super.key, required this.songPaths, this.size = 72});

  final List<String> songPaths;
  final double size;

  @override
  State<PlaylistCollage> createState() => _PlaylistCollageState();
}

class _PlaylistCollageState extends State<PlaylistCollage> {
  List<String?> _artworks = const [];
  List<String> _loadedFor = const [];

  List<String> get _firstFour => widget.songPaths.take(4).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlaylistCollage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_samePaths(_firstFour, _loadedFor)) _load();
  }

  static bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _load() async {
    final paths = _firstFour;
    _loadedFor = paths;
    if (paths.isEmpty) {
      // Called from initState/didUpdateWidget, which rebuild anyway.
      _artworks = const [];
      return;
    }
    final songs = await context.read<SongRepository>().getSongsByPaths(paths);
    if (!mounted || !_samePaths(paths, _loadedFor)) return;
    setState(() => _artworks = [for (final s in songs) s.artworkBase64]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = widget.size;

    if (widget.songPaths.isEmpty) {
      return MiniVinyl(diameter: size, labelColor: colorScheme.primary);
    }

    // Placeholder labels alternate like the design when there's no artwork.
    final placeholders = [
      colorScheme.onSurface,
      colorScheme.primary,
      colorScheme.primary,
      colorScheme.onSurface,
    ];
    const gap = 4.0;
    final cell = (size - gap) / 2;

    return SizedBox.square(
      dimension: size,
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < 4; i++)
            MiniVinyl(
              diameter: cell,
              artworkBase64: i < _artworks.length ? _artworks[i] : null,
              labelColor: placeholders[i],
            ),
        ],
      ),
    );
  }
}

/// A small vinyl: dark disc with a round label (artwork or a solid color).
class MiniVinyl extends StatelessWidget {
  const MiniVinyl({
    super.key,
    required this.diameter,
    required this.labelColor,
    this.artworkBase64,
  });

  final double diameter;
  final Color labelColor;
  final String? artworkBase64;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelSize = diameter * 0.55;
    final bytes = ArtworkCache.decode(artworkBase64);
    final solidLabel = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: labelColor),
      child: Center(
        child: Container(
          width: diameter * 0.06,
          height: diameter * 0.06,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0A0A0A),
          ),
        ),
      ),
    );

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHigh,
      ),
      alignment: Alignment.center,
      child: SizedBox.square(
        dimension: labelSize,
        child: bytes == null
            ? solidLabel
            : ClipOval(
                child: Image(
                  image: ResizeImage(
                    MemoryImage(bytes),
                    width:
                        (labelSize * MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    policy: ResizeImagePolicy.fit,
                  ),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => solidLabel,
                ),
              ),
      ),
    );
  }
}
