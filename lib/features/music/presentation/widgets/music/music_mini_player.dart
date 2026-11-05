import 'dart:async';

import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';
import 'package:widgets/widgets.dart';

class MusicMiniPlayer extends StatelessWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const MusicScreen())),
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 72,
        color: colorScheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            BlocSelector<PlaybackBloc, PlaybackState, String?>(
              selector: (state) => state.song?.artworkBase64,
              builder: (context, artworkBase64) =>
                  _ProgressArtwork(artworkBase64: artworkBase64),
            ),
            const SizedBox(width: 12),

            // Song title / artist
            Expanded(
              child:
                  BlocSelector<PlaybackBloc, PlaybackState, (String?, String?)>(
                    selector: (state) =>
                        (state.song?.title, state.song?.artist),
                    builder: (context, songInfo) {
                      final localizations = AppLocalizations.of(context);
                      final title = songInfo.$1 ?? localizations!.nowPlaying;
                      final artist = songInfo.$2 ?? localizations!.unknown;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            artist,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
            ),

            // Play/Pause
            BlocSelector<PlaybackBloc, PlaybackState, bool>(
              selector: (state) =>
                  state.status == PlaybackStatus.playing ||
                  state.status == PlaybackStatus.loading,
              builder: (context, isPlaying) => MechanixIconButton.standard(
                icon: Image.asset(
                  isPlaying ? MusicIcons.pauseIcon : MusicIcons.resumeIcon,
                  color: colorScheme.onSurface,
                  height: 32,
                  width: 32,
                ),
                isSelected: false,
                onPressed: () => context.read<PlaybackBloc>().add(
                  isPlaying ? const PlaybackPause() : const PlaybackResume(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressArtwork extends StatefulWidget {
  const _ProgressArtwork({required this.artworkBase64});

  final String? artworkBase64;

  @override
  State<_ProgressArtwork> createState() => _ProgressArtworkState();
}

class _ProgressArtworkState extends State<_ProgressArtwork> {
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

    // Position stream
    _positionSub = repo.onPositionChanged.listen((pos) {
      if (!_isTransitioning && _durationMs > 0 && mounted) {
        setState(() {
          _progress = (pos.inMilliseconds / _durationMs).clamp(0.0, 1.0);
        });
      }
    });
  }

  //  Duration stream listener with debounce to avoid flickering on next song
  void _onDurationChanged(int durationMs) {
    _durationMs = durationMs;
    _debounceTimer?.cancel();
    setState(() {
      _isTransitioning = true;
      _progress = 0.0;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _isTransitioning = false);
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
    final theme = Theme.of(context);
    final colorscheme = theme.colorScheme;

    return BlocListener<PlaybackBloc, PlaybackState>(
      listenWhen: (prev, curr) => prev.songDuration != curr.songDuration,
      listener: (_, state) =>
          _onDurationChanged(state.songDuration.inMilliseconds),
      child: RepaintBoundary(
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: _isTransitioning ? 0.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Transform.scale(
                    scaleX: -1, //anticlockwise rotation
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 2,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorscheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              ClipOval(
                child: _ArtworkWidget(artwork: widget.artworkBase64, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  /// Base64 cover art of the song.
  final String? artwork;
  final double size;

  const _ArtworkWidget({required this.artwork, required this.size});

  @override
  Widget build(BuildContext context) {
    final bytes = ArtworkCache.decode(artwork);
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Image.asset(
          MusicIcons.musicNote,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Image.asset(
      MusicIcons.musicNote,
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
