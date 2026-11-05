import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/presentation/screens/playlist_detail_screen.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/playlist_collage.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// The Playlist tab: all playlists, and a "+" button to create one.
class PlaylistsView extends StatelessWidget {
  const PlaylistsView({super.key});

  Future<void> _create(BuildContext context) async {
    final created = Completer<Playlist>();
    context.read<PlaylistBloc>().add(PlaylistCreateRequested(created: created));
    final playlist = await created.future;
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PlaylistDetailScreen(playlistId: playlist.id, isNew: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Stack(
      children: [
        BlocBuilder<PlaylistBloc, PlaylistState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.playlists.isEmpty) {
              return Center(
                key: const ValueKey('playlists_empty'),
                child: Text(
                  l10n.noPlaylists,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
              child: ListView.builder(
                key: const ValueKey('playlists_list'),
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: state.playlists.length,
                itemBuilder: (context, index) =>
                    PlaylistRow(playlist: state.playlists[index]),
              ),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: MechanixFloatingActionButton(
            size: MechanixFloatingActionButtonSize.medium,
            backgroundColor: theme.colorScheme.primary,
            key: const ValueKey('create_playlist_button'),
            tooltip: l10n.createPlaylist,
            icon: Icon(Icons.add, color: theme.colorScheme.onSurface, size: 32),
            onPressed: () => _create(context),
          ),
        ),
      ],
    );
  }
}

class PlaylistRow extends StatelessWidget {
  const PlaylistRow({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final owner = Platform.environment['USER'];
    final tracks = l10n.tracksCount(
      playlist.trackCount.toString().padLeft(2, '0'),
    );

    return InkWell(
      key: ValueKey('playlist_${playlist.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlaylistDetailScreen(playlistId: playlist.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            PlaylistCollage(songPaths: playlist.songPaths),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (owner != null && owner.isNotEmpty) ...[
                          TextSpan(text: owner),
                          TextSpan(
                            text: '  •  ',
                            style: TextStyle(color: theme.colorScheme.primary),
                          ),
                        ],
                        TextSpan(text: tracks),
                      ],
                    ),
                    style: secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
