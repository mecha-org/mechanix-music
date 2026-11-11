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

/// "PLAYING NEXT [n]" header with a horizontal list of the whole queue:
/// songs already played (dimmed), the current song (highlighted), then the
/// songs to come. Nothing disappears as songs play; the list scrolls to
/// keep the current song in view. [n] counts the songs still to come.
class PlayingNext extends StatefulWidget {
  const PlayingNext({super.key});

  static const double artworkSize = 100;

  /// Space between two tiles.
  static const double _gap = 12;

  @override
  State<PlayingNext> createState() => _PlayingNextState();
}

class _PlayingNextState extends State<PlayingNext> {
  final _scroll = ScrollController();
  int? _scrolledTo;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the current song to the start of the list when it changes.
  void _scrollToCurrent(int index) {
    if (index < 0 || index == _scrolledTo) return;
    final first = _scrolledTo == null;
    _scrolledTo = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final offset = (index * (PlayingNext.artworkSize + PlayingNext._gap))
          .clamp(0.0, _scroll.position.maxScrollExtent);
      if (first) {
        _scroll.jumpTo(offset);
      } else {
        _scroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return BlocSelector<PlaybackBloc, PlaybackState, _Queue>(
      selector: (state) => _Queue(state.queue.songs, state.queue.currentIndex),
      builder: (context, queue) {
        final songs = queue.songs;
        final current = queue.currentIndex;
        final upcoming = songs.length - current - 1;
        final count = upcoming.toString().padLeft(2, '0');
        _scrollToCurrent(current);

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
              height: PlayingNext.artworkSize + 48,
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
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: PlayingNext._gap),
                      itemBuilder: (context, index) => _UpNextTile(
                        song: songs[index],
                        isCurrent: index == current,
                        isPlayed: index < current,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({
    required this.song,
    this.isCurrent = false,
    this.isPlayed = false,
  });

  final SongModel song;

  /// The song playing now: accent border and title.
  final bool isCurrent;

  /// Already played: dimmed.
  final bool isPlayed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    const size = PlayingNext.artworkSize;

    return Opacity(
      opacity: isPlayed ? 0.4 : 1,
      child: GestureDetector(
        key: ValueKey('playing_next_${song.path}'),
        behavior: HitTestBehavior.opaque,
        // Tapping the current song does nothing; any other song plays.
        onTap: isCurrent
            ? null
            : () => context.read<PlaybackBloc>().add(PlaybackPlay(song)),
        child: SizedBox(
          width: size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                foregroundDecoration: isCurrent
                    ? BoxDecoration(
                        border: Border.all(color: colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(2),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox.square(
                    dimension: size,
                    child: _Artwork(song: song),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isCurrent ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    final bytes = ArtworkCache.decode(song.artworkBase64);
    final cacheSize =
        (PlayingNext.artworkSize * MediaQuery.devicePixelRatioOf(context))
            .ceil();

    final placeholder = Center(
      child: Image(
        image: ResizeImage(
          const AssetImage(MusicIcons.musicIcon),
          width: cacheSize,
          height: cacheSize,
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      ),
    );

    if (bytes == null) return placeholder;

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

/// The queue compared by path, title, artist and artwork plus the current
/// position, so the list only rebuilds when what it shows changes (not on
/// every state emission).
class _Queue extends Equatable {
  const _Queue(this.songs, this.currentIndex);

  final List<SongModel> songs;
  final int currentIndex;

  @override
  List<Object?> get props => [
    currentIndex,
    for (final s in songs) (s.path, s.title, s.artist, s.artworkBase64),
  ];
}
