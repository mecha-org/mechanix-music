import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';

/// "PLAYING NEXT [n]" header with a horizontal list of the upcoming songs.
class PlayingNext extends StatelessWidget {
  const PlayingNext({super.key});

  static const double artworkSize = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return BlocSelector<PlaybackBloc, PlaybackState, _UpNext>(
      selector: (state) => _UpNext(state.upNext),
      builder: (context, upNext) {
        final songs = upNext.songs;
        final count = songs.length.toString().padLeft(2, '0');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.playingNext.toUpperCase(), style: headerStyle),
                  Text('[$count]', style: headerStyle),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: artworkSize + 48,
              child: songs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.noTracksAvailable,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      key: const ValueKey('playing_next_list'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) =>
                          _UpNextTile(song: songs[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({required this.song});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = PlayingNext.artworkSize;

    return GestureDetector(
      key: ValueKey('playing_next_${song.path}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<PlaybackBloc>().add(PlaybackPlay(song)),
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox.square(dimension: size, child: _Artwork(song: song)),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.song});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: ImageIcon(
          const AssetImage(MusicIcons.musicIcon),
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    final bytes = ArtworkCache.decode(song.artworkBase64);
    if (bytes == null) return placeholder;

    final cacheSize =
        (PlayingNext.artworkSize * MediaQuery.devicePixelRatioOf(context))
            .ceil();
    return Image(
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
  }
}

/// Upcoming songs compared by path, title, artist and artwork, so the list
/// only rebuilds when what it shows changes (not on every state emission).
class _UpNext extends Equatable {
  const _UpNext(this.songs);

  final List<SongModel> songs;

  @override
  List<Object?> get props => [
    for (final s in songs) (s.path, s.title, s.artist, s.artworkBase64),
  ];
}
