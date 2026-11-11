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
  /// As in the design, the vinyl's centre (the spindle hole) sits exactly on
  /// the screen's left edge, so half of it shows.
  static const double vinylVisibleWidth = vinylSize / 2;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 16),
            SizedBox(
              height: vinylSize,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: vinylVisibleWidth - vinylSize,
                    top: 0,
                    child: LandingVinyl(size: vinylSize),
                  ),
                  Positioned.fill(
                    left: vinylVisibleWidth + 26,
                    right: 20,
                    child: _NowPlayingDetails(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            MechanixDivider(),
            SizedBox(height: 16),
            PlayingNext(),
            SizedBox(height: 16),
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
      selector: (state) =>
          (title: state.song?.title, artist: state.song?.artist),
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
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSecondaryFixed,
              ),
            ),
          ],
        );
      },
    );
  }
}
