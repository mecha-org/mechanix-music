import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
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
    final List<SongModel> songs;
    try {
      songs = await context.read<SongRepository>().getSongsByPaths(paths);
    } catch (e) {
      // The library could not be opened (e.g. another instance holds it):
      // keep the placeholder labels instead of an unhandled error.
      AppLogger.e('[PlaylistCollage] Loading artwork failed: $e');
      return;
    }
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

    // Placeholder labels alternate like the design when there's no artwork:
    // light grey and accent orange.
    final placeholders = [
      colorScheme.onPrimaryFixed,
      colorScheme.primary,
      colorScheme.primary,
      colorScheme.onPrimaryFixed,
    ];
    // The four vinyls touch, as in the design (128 px → four 64 px discs).
    const gap = 0.0;
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

/// A small vinyl: dark grooved disc with a round label (artwork or a solid
/// color) and a spindle hole.
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

  /// Label diameter relative to the disc.
  static const double _labelRatio = 0.5;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelSize = diameter * _labelRatio;
    final bytes = ArtworkCache.decode(artworkBase64);
    final hole = Container(
      width: diameter * 0.03,
      height: diameter * 0.03,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerLowest,
      ),
    );
    final solidLabel = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: labelColor),
      child: Center(child: hole),
    );

    return SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: _GroovesPainter(
          labelRatio: _labelRatio,
          discColor: colorScheme.surfaceContainerLow,
          grooveColor: colorScheme.surfaceContainerHigh,
          rimColor: colorScheme.surfaceContainerLowest,
        ),
        child: Center(
          child: SizedBox.square(
            dimension: labelSize,
            child: bytes == null
                ? solidLabel
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipOval(
                        child: Image(
                          image: ResizeImage(
                            MemoryImage(bytes),
                            width:
                                (labelSize *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                            policy: ResizeImagePolicy.fit,
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => solidLabel,
                        ),
                      ),
                      Center(child: hole),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The vinyl disc: a dark circle with fine concentric grooves between the
/// label and the rim, as in the design.
class _GroovesPainter extends CustomPainter {
  const _GroovesPainter({
    required this.labelRatio,
    required this.discColor,
    required this.grooveColor,
    required this.rimColor,
  });

  final double labelRatio;
  final Color discColor;
  final Color grooveColor;
  final Color rimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = discColor);

    // About ten grooves on a 64 px disc, scaling with the disc.
    final spacing = size.shortestSide * 0.024;
    final groove = Paint()
      ..color = grooveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.008
      ..isAntiAlias = true;
    final first = radius * labelRatio + spacing;
    for (var r = first; r < radius - spacing; r += spacing) {
      canvas.drawCircle(center, r, groove);
    }

    canvas.drawCircle(
      center,
      radius - size.shortestSide * 0.006,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.012,
    );
  }

  @override
  bool shouldRepaint(_GroovesPainter oldDelegate) =>
      oldDelegate.labelRatio != labelRatio ||
      oldDelegate.discColor != discColor ||
      oldDelegate.grooveColor != grooveColor ||
      oldDelegate.rimColor != rimColor;
}
