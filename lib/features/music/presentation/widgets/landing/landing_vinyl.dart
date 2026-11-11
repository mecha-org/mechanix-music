import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';

/// Vinyl record with the current song's artwork as its label.
///
/// As in the design: a dark disc with evenly spaced fine grooves from the
/// label out to near the edge (no rim line), the artwork as the label and a
/// spindle hole in the middle. When nothing is playing
/// (or the song has no artwork) the label is an empty dark disc.
class LandingVinyl extends StatelessWidget {
  const LandingVinyl({super.key, required this.size});

  final double size;

  /// Label diameter relative to the disc.
  static const double labelRatio = 0.5;

  @override
  Widget build(BuildContext context) {
    final labelSize = size * labelRatio;
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _VinylPainter(
                discColor: colorScheme.surfaceContainerLow,
                grooveColor: colorScheme.outline,
                labelRatio: labelRatio,
              ),
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
            // Spindle hole.
            Container(
              width: size * 0.03,
              height: size * 0.03,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceContainerLowest,
              ),
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

    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image(
      image: ResizeImage(
        MemoryImage(bytes),
        width: pixels,
        height: pixels,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => empty,
    );
  }
}

/// Dark disc with fine concentric grooves from the label to near the edge.
class _VinylPainter extends CustomPainter {
  const _VinylPainter({
    required this.discColor,
    required this.grooveColor,
    required this.labelRatio,
  });

  final Color discColor;
  final Color grooveColor;
  final double labelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = discColor);

    // Measured from the design: a groove every ~4% of the radius, the first
    // one at the label's edge and the last ~6% inside the edge.
    final spacing = radius * 0.042;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true
      ..color = grooveColor.withValues(alpha: 0.8);
    for (var r = radius * labelRatio; r <= radius * 0.94; r += spacing) {
      canvas.drawCircle(center, r, groove);
    }
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) =>
      oldDelegate.discColor != discColor ||
      oldDelegate.grooveColor != grooveColor ||
      oldDelegate.labelRatio != labelRatio;
}
