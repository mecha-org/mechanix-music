import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_artwork.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_menu.dart';
import 'package:widgets/widgets.dart';

/// A song row inside a playlist: tap to play the playlist from this song,
/// drag the handle to reorder, swipe for the menu (play next, favourite,
/// remove).
class PlaylistTrackTile extends StatelessWidget {
  const PlaylistTrackTile({
    super.key,
    required this.index,
    required this.song,
    required this.playlistId,
    required this.playlistSongs,
  });

  /// Position in the reorderable list (for the drag handle).
  final int index;
  final SongModel song;
  final String playlistId;

  /// The playlist's songs, used as the play queue.
  final List<SongModel> playlistSongs;

  void _play(BuildContext context) {
    final playback = context.read<PlaybackBloc>();
    playback.add(PlaybackListUpdated(playlistSongs, followsLibrary: false));
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
            // The playing song's row, as in the design (not orange-tinted).
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
          trailingWidgets: [
            ReorderableDragStartListener(
              index: index,
              child: Image.asset(
                MusicIcons.dragHandle,
                key: ValueKey('drag_handle_${song.path}'),
                width: 24,
                height: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          onTap: () => _play(context),
          actions: [
            TrackMenu(
              song: song,
              showAddToPlaylist: false,
              showSleepTimer: false,
              onRemove: () => context.read<PlaylistBloc>().add(
                PlaylistSongRemoved(playlistId, song.path),
              ),
            ),
          ],
        );
      },
    );
  }
}
