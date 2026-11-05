import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_controls.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_progress.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_vinyl.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/playing_next.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// The Player tab: the current song on a vinyl with its progress and
/// controls, followed by the songs playing next.
///
/// With nothing playing it shows the empty state ("START PLAYING...").
class NowPlayingLanding extends StatelessWidget {
  const NowPlayingLanding({super.key});

  static const double vinylSize = 240;

  /// How much of the vinyl is visible; the rest is cut off on the left.
  static const double vinylVisibleWidth = 126;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: vinylSize,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  const Positioned(
                    left: vinylVisibleWidth - vinylSize,
                    top: 0,
                    child: LandingVinyl(size: vinylSize),
                  ),
                  Positioned.fill(
                    left: vinylVisibleWidth + 20,
                    right: 20,
                    child: const _NowPlayingDetails(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const MechanixDivider(),
            const SizedBox(height: 16),
            const PlayingNext(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingDetails extends StatelessWidget {
  const _NowPlayingDetails();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SongTitle(),
        SizedBox(height: 20),
        LandingProgress(),
        SizedBox(height: 16),
        LandingControls(),
      ],
    );
  }
}

class _SongTitle extends StatelessWidget {
  const _SongTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocSelector<
      PlaybackBloc,
      PlaybackState,
      ({String? title, String? artist})
    >(
      selector: (state) => (title: state.song?.title, artist: state.song?.artist),
      builder: (context, song) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (song.title ?? l10n.startPlaying).toUpperCase(),
              key: const ValueKey('landing_song_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.artist ?? l10n.artist,
              key: const ValueKey('landing_song_artist'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
