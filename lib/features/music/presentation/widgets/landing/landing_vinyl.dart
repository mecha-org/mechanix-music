import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';

/// Vinyl record with the current song's artwork as its label.
///
/// When nothing is playing (or the song has no artwork) the label is an
/// empty dark disc, as in the empty-state design.
class LandingVinyl extends StatelessWidget {
  const LandingVinyl({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final labelSize = size * 0.5;
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _VinylPainter(grooveColor: colorScheme.outline),
            ),
            BlocSelector<PlaybackBloc, PlaybackState, String?>(
              selector: (state) => state.song?.artworkBase64,
              builder: (context, artworkBase64) {
                return ClipOval(
                  child: SizedBox.square(
                    dimension: labelSize,
                    child: _Label(
                      artworkBase64: artworkBase64,
                      size: labelSize,
                      emptyColor: colorScheme.surfaceContainer,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.artworkBase64,
    required this.size,
    required this.emptyColor,
  });

  final String? artworkBase64;
  final double size;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final bytes = ArtworkCache.decode(artworkBase64);
    final empty = ColoredBox(color: emptyColor);
    if (bytes == null) return empty;

    return Image(
      image: ResizeImage(
        MemoryImage(bytes),
        width: size.ceil(),
        height: size.ceil(),
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      errorBuilder: (_, _, _) => empty,
    );
  }
}

/// Black disc with concentric grooves.
class _VinylPainter extends CustomPainter {
  const _VinylPainter({required this.grooveColor});

  final Color grooveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF0A0A0A));

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grooveColor.withValues(alpha: 0.6);
    for (var r = radius * 0.56; r < radius - 1; r += radius * 0.035) {
      canvas.drawCircle(center, r, groove);
    }

    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = grooveColor,
    );
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) =>
      oldDelegate.grooveColor != grooveColor;
}
