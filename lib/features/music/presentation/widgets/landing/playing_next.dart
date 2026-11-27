import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// "PLAYING NEXT [n]" header with a horizontal list of the whole queue:
/// songs already played (dimmed), the current song (highlighted), then the
/// songs to come. Nothing disappears as songs play; the list scrolls to
/// keep the current song in view. [n] counts the songs still to come.
///
/// The edit button turns on editing: songs still to come can be moved
/// (long-press, then drag) or removed with ×.
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
  bool _editing = false;

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

    // Selects only what the queue is made of. Records compare lists by
    // identity, so this check is O(1) on every state emission (play/pause,
    // duration, sleep timer…); the queue is only rebuilt when it changes.
    return BlocSelector<PlaybackBloc, PlaybackState, Object?>(
      selector: (s) => (
        s.playbackList,
        s.shuffledList,
        s.playNextQueue,
        s.isShuffled,
        s.song?.path,
        s.currentIndex,
        s.anchorPath,
        s.unloadedCount,
      ),
      builder: (context, _) {
        final state = context.read<PlaybackBloc>().state;
        final queue = state.queue; // once
        final songs = queue.songs;
        final current = queue.currentIndex;
        final upcoming = songs.length - current - 1;
        // Includes songs not loaded yet, so it stays put while scrolling.
        final toCome = upcoming + state.unloadedCount;
        final count = toCome.toString().padLeft(2, '0');
        _scrollToCurrent(current);
        // Nothing left to edit: editing ends (and stays off when songs are
        // queued again).
        if (upcoming == 0) _editing = false;
        final editing = _editing;

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
                  const Spacer(),
                  Text('[$count]', style: headerStyle),
                  if (upcoming > 0) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label: editing ? l10n.doneEditing : l10n.editQueue,
                      child: MechanixIconButton.standard(
                        key: const ValueKey('playing_next_edit'),
                        type: IconButtonType.rounded,
                        size: IconButtonSize.small,
                        icon: Image.asset(
                          editing ? MusicIcons.check : MusicIcons.edit,
                          color: theme.colorScheme.primary,
                          width: 20,
                          height: 20,
                        ),
                        onPressed: () => setState(() {
                          _editing = !editing;
                          // The list is rebuilt: keep the current song in
                          // view.
                          _scrolledTo = null;
                        }),
                      ),
                    ),
                  ],
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
                  : editing
                  ? _EditableQueue(
                      controller: _scroll,
                      songs: songs,
                      current: current,
                    )
                  : ListView.separated(
                      key: const ValueKey('playing_next_list'),
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: PlayingNext._gap),
                      itemBuilder: (context, index) {
                        _loadMoreAt(context, index, songs.length);
                        return _UpNextTile(
                          song: songs[index],
                          isCurrent: index == current,
                          isPlayed: index < current,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The queue while editing: songs still to come can be moved (long-press,
/// then drag, anywhere after the current song) and removed. Played songs
/// and the current song stay put. A long press leaves swipes to scrolling.
class _EditableQueue extends StatelessWidget {
  const _EditableQueue({
    required this.controller,
    required this.songs,
    required this.current,
  });

  final ScrollController controller;
  final List<SongModel> songs;

  /// Index of the current song in [songs]; -1 when nothing is loaded.
  final int current;

  /// Position in [PlaybackState.upNext] of the song at [index] in [songs].
  int _upNextIndex(int index) => index - current - 1;

  void _onReorder(BuildContext context, int from, int to) {
    if (from <= current) return;
    final target = to <= current ? current + 1 : to;
    context.read<PlaybackBloc>().add(
      PlaybackQueueMoved(_upNextIndex(from), _upNextIndex(target)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      key: const ValueKey('playing_next_editable_list'),
      scrollController: controller,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      buildDefaultDragHandles: false,
      itemCount: songs.length,
      onReorderItem: (from, to) => _onReorder(context, from, to),
      proxyDecorator: (child, _, _) =>
          Material(type: MaterialType.transparency, child: child),
      itemBuilder: (context, index) {
        _loadMoreAt(context, index, songs.length);
        final song = songs[index];
        final upcoming = index > current;
        final tile = _UpNextTile(
          song: song,
          isCurrent: index == current,
          isPlayed: index < current,
          editing: true,
          onRemove: upcoming
              ? () => context.read<PlaybackBloc>().add(
                  PlaybackQueueRemoved(_upNextIndex(index)),
                )
              : null,
        );
        return Padding(
          key: ValueKey('playing_next_edit_${index}_${song.path}'),
          padding: const EdgeInsets.only(right: PlayingNext._gap),
          child: upcoming
              ? ReorderableDelayedDragStartListener(index: index, child: tile)
              : tile,
        );
      },
    );
  }
}

/// Loads more songs when the last tile is built.
void _loadMoreAt(BuildContext context, int index, int length) {
  if (index == length - 1) {
    context.read<PlaybackBloc>().add(const PlaybackQueueEndReached());
  }
}

class _UpNextTile extends StatelessWidget {
  const _UpNextTile({
    required this.song,
    this.isCurrent = false,
    this.isPlayed = false,
    this.editing = false,
    this.onRemove,
  });

  final SongModel song;

  /// The song playing now: accent border and title.
  final bool isCurrent;

  /// Already played: dimmed.
  final bool isPlayed;

  /// Editing the queue: tapping does not play.
  final bool editing;

  /// Shows a remove (×) button on the artwork when set.
  final VoidCallback? onRemove;

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
        onTap: isCurrent || editing
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
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Artwork(song: song),
                        if (onRemove case final remove?)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: _RemoveButton(
                              key: ValueKey('playing_next_remove_${song.path}'),
                              onPressed: remove,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isCurrent
                      ? colorScheme.primary
                      : colorScheme.onSurface,
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

/// Small × on a queued song's artwork (32 px, 48 px tap area). Screen
/// readers announce "Remove from queue".
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context)!.removeFromQueue,
      child: MechanixIconButton.filled(
        type: IconButtonType.rounded,
        size: IconButtonSize.xSmall,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.9,
        ),
        foregroundColor: colorScheme.onSurface,
        icon: Image.asset(
          MusicIcons.closeIcon,
          color: colorScheme.onSurface,
          width: 16,
          height: 16,
        ),
        onPressed: onPressed,
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
          const AssetImage(MusicIcons.artworkIcon),
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
