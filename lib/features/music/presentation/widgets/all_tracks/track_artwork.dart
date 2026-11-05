import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:mechanix_music/core/utils/icons.dart';

/// Round song artwork for track rows, with an accent ring when [highlighted]
/// (the song that is currently playing).
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.artworkBase64,
    this.size = 56,
    this.highlighted = false,
  });

  final String? artworkBase64;
  final double size;
  final bool highlighted;

  static const double _ringWidth = 3;

  /// Background colour of the placeholder asset ([MusicIcons.musicIcon]).
  static const Color _placeholderBackground = Color(0xFFECE6F0);

  /// Side of the placeholder asset in pixels and the width of its dark edge.
  static const double _assetSize = 112;
  static const double _assetEdge = 4;

  /// Placeholder size relative to the circle.
  static const double _placeholderScale = 0.8;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bytes = ArtworkCache.decode(artworkBase64);
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    // The placeholder asset is a rounded square with a thin dark edge and
    // shapes that nearly fill it, so clipped to a circle the shapes touch
    // the rim. Show it smaller, without its edge, on a circle of the same
    // background colour instead.
    final diameter = size - (highlighted ? _ringWidth * 2 : 0);
    final iconSize = diameter * _placeholderScale;
    const visible = (_assetSize - 2 * _assetEdge) / _assetSize;
    final placeholder = ColoredBox(
      color: _placeholderBackground,
      child: Center(
        child: ClipRect(
          child: Align(
            widthFactor: visible,
            heightFactor: visible,
            child: Image(
              image: ResizeImage(
                const AssetImage(MusicIcons.musicIcon),
                width: cacheSize,
                height: cacheSize,
                policy: ResizeImagePolicy.fit,
              ),
              width: iconSize / visible,
              height: iconSize / visible,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );

    final image = bytes == null
        ? placeholder
        : Image(
            image: ResizeImage(
              MemoryImage(bytes),
              width: cacheSize,
              height: cacheSize,
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => placeholder,
          );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(highlighted ? _ringWidth : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? colorScheme.primary : null,
      ),
      child: ClipOval(child: image),
    );
  }
}
