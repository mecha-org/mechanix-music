import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_artwork.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_mini_player.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/playlist_collage.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/playlist_track_tile.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/rename_playlist_sheet.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// A playlist: its songs (reorderable, swipe for the menu) followed by the
/// library songs that can be added to it. [isNew] shows the "Create
/// playlist" title for a playlist that was just created.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    this.isNew = false,
  });

  final String playlistId;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: MechanixAppBar.small(
        primary: false,
        backgroundColor: Colors.transparent,
        leading: MechanixIconButton.standard(
          key: const ValueKey('playlist_back_button'),
          type: IconButtonType.rounded,
          icon: Icon(Icons.chevron_left, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: isNew ? Text(l10n.createPlaylist) : null,
      ),
      body: BlocSelector<PlaylistBloc, PlaylistState, Playlist?>(
        selector: (state) => state.byId(playlistId),
        builder: (context, playlist) {
          if (playlist == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _PlaylistBody(playlist: playlist);
        },
      ),
      bottomNavigationBar: BlocSelector<PlaybackBloc, PlaybackState, bool>(
        selector: (state) => state.song != null,
        builder: (context, hasSong) =>
            hasSong ? const MusicMiniPlayer() : const SizedBox.shrink(),
      ),
    );
  }
}

class _PlaylistBody extends StatefulWidget {
  const _PlaylistBody({required this.playlist});

  final Playlist playlist;

  @override
  State<_PlaylistBody> createState() => _PlaylistBodyState();
}

class _PlaylistBodyState extends State<_PlaylistBody> {
  /// Library songs of the playlist, by path. Filled lazily so reordering
  /// or adding a song doesn't reload (and flicker) the whole list.
  final Map<String, SongModel> _songsByPath = {};

  @override
  void initState() {
    super.initState();
    _fetchMissing();
  }

  @override
  void didUpdateWidget(_PlaylistBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchMissing();
  }

  Future<void> _fetchMissing() async {
    final missing = widget.playlist.songPaths
        .where((p) => !_songsByPath.containsKey(p))
        .toList();
    if (missing.isEmpty) return;
    final songs = await context.read<SongRepository>().getSongsByPaths(missing);
    if (!mounted) return;
    setState(() {
      for (final song in songs) {
        _songsByPath[song.path] = song;
      }
    });
  }

  /// Playlist songs in order (paths whose file left the library are hidden).
  List<SongModel> get _songs => [
    for (final path in widget.playlist.songPaths) ?_songsByPath[path],
  ];

  void _onReorder(List<SongModel> shown, int oldIndex, int newIndex) {
    // Map indices of the shown rows back to the playlist's paths.
    final paths = widget.playlist.songPaths;
    final from = paths.indexOf(shown[oldIndex].path);
    final to = newIndex >= shown.length
        ? paths.length
        : paths.indexOf(shown[newIndex].path);
    if (from == -1 || to == -1) return;
    context.read<PlaylistBloc>().add(
      PlaylistSongMoved(widget.playlist.id, from, to),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlist = widget.playlist;
    final songs = _songs;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
      ),
      child: MechanixSwipableList(
        child: CustomScrollView(
          key: const ValueKey('playlist_detail_scroll'),
          slivers: [
            SliverToBoxAdapter(child: _Header(playlist: playlist)),
            SliverReorderableList(
              itemCount: songs.length,
              onReorder: (oldIndex, newIndex) =>
                  _onReorder(songs, oldIndex, newIndex),
              itemBuilder: (context, index) => PlaylistTrackTile(
                key: ValueKey('playlist_track_${songs[index].path}'),
                index: index,
                song: songs[index],
                playlistId: playlist.id,
                playlistSongs: songs,
              ),
            ),
            SliverToBoxAdapter(child: _AddTracksHeader(playlist: playlist)),
            _AddTracksList(playlist: playlist),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaylistCollage(songPaths: playlist.songPaths),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name.toUpperCase(),
                    key: const ValueKey('playlist_detail_name'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tracksCount(
                      playlist.trackCount.toString().padLeft(2, '0'),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Favourites is a fixed playlist: it cannot be renamed.
          if (!playlist.isFixed)
            MechanixIconButton.standard(
              key: const ValueKey('rename_playlist_button'),
              type: IconButtonType.rounded,
              size: IconButtonSize.small,
              icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
              onPressed: () => showRenamePlaylistSheet(context, playlist),
            ),
        ],
      ),
    );
  }
}

class _AddTracksHeader extends StatelessWidget {
  const _AddTracksHeader({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const MechanixDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            AppLocalizations.of(context)!.addTracksTo(playlist.name),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Library songs that are not in the playlist yet, each with a "+" button.
class _AddTracksList extends StatelessWidget {
  const _AddTracksList({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SongBloc, SongState>(
      builder: (context, state) {
        if (state is! SongLoaded) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final inPlaylist = playlist.songPaths.toSet();
        final candidates = state.songs
            .where((s) => !inPlaylist.contains(s.path))
            .toList();

        return SliverList.builder(
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            // Load the next library page when the end is reached.
            if (index == candidates.length - 1 && state.hasMore) {
              context.read<SongBloc>().add(const SongLoadMore());
            }
            final song = candidates[index];
            return MechanixListTile(
              key: ValueKey('add_track_${song.path}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leadingWidgets: [TrackArtwork(artworkBase64: song.artworkBase64)],
              label: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              supportingText: song.artist,
              trailingText: song.duration,
              trailingWidgets: [
                MechanixIconButton.filled(
                  key: ValueKey('add_track_button_${song.path}'),
                  type: IconButtonType.rounded,
                  size: IconButtonSize.xSmall,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
                  onPressed: () => context.read<PlaylistBloc>().add(
                    PlaylistSongAdded(playlist.id, song.path),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
