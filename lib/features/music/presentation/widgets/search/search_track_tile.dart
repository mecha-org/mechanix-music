import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_artwork.dart';
import 'package:widgets/widgets.dart';

/// A song row of the search screen: artwork (ringed while playing), title
/// and artist, and either the duration (results) or a remove button
/// (recent searches).
class SearchTrackTile extends StatelessWidget {
  const SearchTrackTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onRemove,
  });

  final SongModel song;
  final VoidCallback onTap;

  /// Shows an X that removes the song from the recent searches.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocSelector<PlaybackBloc, PlaybackState, bool>(
      selector: (state) => state.song?.path == song.path,
      builder: (context, isCurrent) {
        final remove = onRemove;
        return MechanixListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          leadingWidgets: [
            TrackArtwork(artworkBase64: song.artworkBase64, highlighted: isCurrent),
          ],
          label: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          supportingText: song.artist,
          trailingText: remove == null ? song.duration : null,
          trailingWidgets: [
            if (remove != null)
              MechanixIconButton.standard(
                key: ValueKey('search_recent_remove_${song.path}'),
                type: IconButtonType.rounded,
                size: IconButtonSize.small,
                icon: ImageIcon(
                  const AssetImage(MusicIcons.closeIcon),
                  size: 18,
                  color: colorScheme.onSurface,
                ),
                onPressed: remove,
              ),
          ],
          onTap: onTap,
        );
      },
    );
  }
}
