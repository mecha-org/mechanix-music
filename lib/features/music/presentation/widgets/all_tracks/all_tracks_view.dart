import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/helper.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/all_tracks_tile.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// The All tracks tab: the library as a swipeable list. Swiping a row
/// reveals its menu (play next, add to playlist, favourite, sleep timer).
class AllTracksView extends StatelessWidget {
  const AllTracksView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final messageStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return BlocBuilder<SongBloc, SongState>(
      builder: (context, state) {
        return switch (state) {
          SongInitial() || SongLoading() => const Center(
            key: ValueKey('all_tracks_loading'),
            child: CircularProgressIndicator(),
          ),
          SongError(:final errorType) => Center(
            key: const ValueKey('all_tracks_error'),
            child: Text(songErrorMessage(l10n, errorType), style: messageStyle),
          ),
          SongLoaded(:final songs) when songs.isEmpty => Center(
            key: const ValueKey('all_tracks_empty'),
            child: Text(l10n.noTracksAvailable, style: messageStyle),
          ),
          SongLoaded() => _TrackList(state: state),
        };
      },
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({required this.state});

  final SongLoaded state;

  @override
  Widget build(BuildContext context) {
    final songs = state.songs;
    final showLoader = state.isLoadingMore;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: MechanixSwipableList(
        key: const ValueKey('all_tracks_list'),
        child: ListView.builder(
          itemCount: songs.length + (showLoader ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= songs.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Fetch the next page when the last row is built. SongBloc
            // ignores the request while a page is loading or none is left.
            if (index == songs.length - 1 && state.hasMore) {
              context.read<SongBloc>().add(const SongLoadMore());
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AllTracksTile(
                key: ValueKey(songs[index].path),
                song: songs[index],
              ),
            );
          },
        ),
      ),
    );
  }
}
