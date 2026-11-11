import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_artwork.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_menu.dart';
import 'package:widgets/widgets.dart';

/// A library song row. Tapping plays it in place (the mini player shows
/// it); swiping left reveals the track menu.
class AllTracksTile extends StatelessWidget {
  const AllTracksTile({super.key, required this.song});

  final SongModel song;

  void _play(BuildContext context) {
    final playback = context.read<PlaybackBloc>();
    final library = context.read<SongBloc>().state;

    // Play from the library order (the queue may hold a folder's songs).
    if (library is SongLoaded) {
      playback.add(PlaybackListUpdated(library.songs));
    }
    playback.add(PlaybackPlay(song));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocSelector<PlaybackBloc, PlaybackState, bool>(
      selector: (state) => state.song?.path == song.path,
      builder: (context, isCurrent) {
        return MechanixSwipableListTile(
          extentRatio: 0.16,
          swipedBackgroundColor: theme.colorScheme.outlineVariant,
          theme: ListTileThemeDataConfig(
            selectedColor: theme.colorScheme.surfaceContainerLow,
            supportingTextStyle: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSecondaryFixedVariant,
            ),
            trailingTextStyle: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          // The ⋮ action opens the track menu; TrackMenu closes the swipe
          // when the menu closes, so it must not close on tap.
          autoClose: false,
          selected: isCurrent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          leadingWidgets: [
            TrackArtwork(
              artworkBase64: song.artworkBase64,
              highlighted: isCurrent,
            ),
          ],
          label: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          supportingText: song.artist,
          trailingText: song.duration,
          onTap: () => _play(context),
          actions: [TrackMenu(song: song)],
        );
      },
    );
  }
}
