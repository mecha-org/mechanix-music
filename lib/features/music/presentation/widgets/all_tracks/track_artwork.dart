import 'dart:async';

import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

/// Round song artwork for track rows. When [highlighted] (the song that is
/// playing) it shows the playback progress ring, like the mini player.
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

  /// Background colour of the placeholder asset ([MusicIcons.musicIcon]).
  static const Color _placeholderBackground = Color(0xFFECE6F0);

  /// Side of the placeholder asset in pixels and the width of its dark edge.
  static const double _assetSize = 112;
  static const double _assetEdge = 4;

  /// Placeholder size relative to the circle.
  static const double _placeholderScale = 0.8;

  @override
  Widget build(BuildContext context) {
    // Always square: if the row gives less room than [size], the whole
    // circle shrinks instead of being squashed or cut off.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: highlighted
          ? ProgressArtwork(artworkBase64: artworkBase64, size: size)
          : ArtworkCircle(artworkBase64: artworkBase64, size: size),
    );
  }
}

/// Round artwork inside a [CircularProgressIndicator] showing how far the
/// current song has played. Used by the mini player and the playing row.
///
/// The ring is [size] across and [strokeWidth] thick; the artwork reaches
/// the middle of the ring.
class ProgressArtwork extends StatefulWidget {
  const ProgressArtwork({
    super.key,
    required this.artworkBase64,
    required this.size,
    this.strokeWidth = 4,
  });

  final String? artworkBase64;
  final double size;
  final double strokeWidth;

  @override
  State<ProgressArtwork> createState() => _ProgressArtworkState();
}

class _ProgressArtworkState extends State<ProgressArtwork> {
  double _progress = 0.0;
  bool _isTransitioning = false;
  int _durationMs = 0;

  Timer? _debounceTimer;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    final repo = context.read<PlaybackRepository>();

    // Seed duration immediately
    _durationMs = context
        .read<PlaybackBloc>()
        .state
        .songDuration
        .inMilliseconds;

    _positionSub = repo.onPositionChanged.listen(_onPosition);
    // Show the current position straight away (a row that scrolls into
    // view mid-song), not only from the next update.
    repo.getCurrentPosition().then((pos) {
      if (pos != null) _onPosition(pos);
    });
  }

  void _onPosition(Duration pos) {
    if (!_isTransitioning && _durationMs > 0 && mounted) {
      setState(() {
        _progress = (pos.inMilliseconds / _durationMs).clamp(0.0, 1.0);
      });
    }
  }

  // Duration listener with debounce to avoid flickering on next song
  void _onDurationChanged(int durationMs) {
    _durationMs = durationMs;
    _debounceTimer?.cancel();
    setState(() {
      _isTransitioning = true;
      _progress = 0.0;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      // Only gates position updates; nothing to redraw.
      _isTransitioning = false;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = widget.size;

    return BlocListener<PlaybackBloc, PlaybackState>(
      listenWhen: (prev, curr) => prev.songDuration != curr.songDuration,
      listener: (_, state) =>
          _onDurationChanged(state.songDuration.inMilliseconds),
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: size,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: widget.strokeWidth,
                  strokeCap: StrokeCap.round,
                  backgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.12,
                  ),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              ArtworkCircle(
                artworkBase64: widget.artworkBase64,
                // Reaches the middle of the ring, as in the mini player.
                size: size - widget.strokeWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Song artwork clipped to a circle, or the placeholder when the song has
/// none.
class ArtworkCircle extends StatelessWidget {
  const ArtworkCircle({
    super.key,
    required this.artworkBase64,
    required this.size,
  });

  final String? artworkBase64;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = ArtworkCache.decode(artworkBase64);
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil();

    // The placeholder asset is a rounded square with a thin dark edge and
    // shapes that nearly fill it, so clipped to a circle the shapes touch
    // the rim. Show it smaller, without its edge, on a circle of the same
    // background colour instead.
    final iconSize = size * TrackArtwork._placeholderScale;
    const visible =
        (TrackArtwork._assetSize - 2 * TrackArtwork._assetEdge) /
        TrackArtwork._assetSize;
    // Clipped to the circle: the image's square corners would otherwise
    // stick out past the round background.
    final placeholder = ClipOval(
      child: ColoredBox(
        color: TrackArtwork._placeholderBackground,
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
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: bytes == null
          ? placeholder
          : ClipOval(
              child: Image(
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
              ),
            ),
    );
  }
}
