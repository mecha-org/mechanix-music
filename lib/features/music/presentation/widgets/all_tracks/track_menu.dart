import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/add_to_playlist_sheet.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/sleep_timer_sheet.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

enum TrackAction {
  playNext,
  addToPlaylist,
  favourite,
  share,
  sleepTimer,
  remove,
}

/// The "⋮" button revealed by swiping a track, opening the track menu.
///
/// The swiped row stays open while the menu is open and closes when the
/// menu closes: after an option is picked or on a tap outside the menu.
///
/// All tracks shows every action. Playlist rows hide "Add to playlist" and
/// "Set sleep timer" and add "Remove" (from the playlist) via [onRemove].
class TrackMenu extends StatelessWidget {
  const TrackMenu({
    super.key,
    required this.song,
    this.showAddToPlaylist = true,
    this.showSleepTimer = true,
    this.onRemove,
  });

  final SongModel song;
  final bool showAddToPlaylist;
  final bool showSleepTimer;

  /// Shows a "Remove" entry when set.
  final VoidCallback? onRemove;

  void _onSelected(BuildContext context, TrackAction action) {
    final l10n = AppLocalizations.of(context)!;

    void notify(String text) => MechanixSnackbar.text(
      position: MechanixSnackbarPosition.top,
      text: text,
    ).show(context);

    switch (action) {
      case TrackAction.playNext:
        context.read<PlaybackBloc>().add(PlaybackQueueNext(song));
        notify(l10n.playingNextSong(song.title));
      case TrackAction.addToPlaylist:
        showAddToPlaylistSheet(context, song);
      case TrackAction.favourite:
        context.read<SongBloc>().add(SongToggleFavourite(song));
      case TrackAction.share:
        // No share target on Mechanix OS yet: copy the file path instead.
        Clipboard.setData(ClipboardData(text: song.path));
        notify(l10n.filePathCopied);
      case TrackAction.sleepTimer:
        showSleepTimerSheet(context);
      case TrackAction.remove:
        onRemove?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.titleLarge?.copyWith(
      color: theme.colorScheme.onSurface,
    );

    MechanixMenuItem<TrackAction> item(
      TrackAction value,
      Widget icon,
      String label, {
      Color? color,
    }) {
      final itemColor = color ?? theme.colorScheme.onSurface;
      return MechanixMenuItem<TrackAction>(
        value: value,
        leading: IconTheme(
          data: IconThemeData(size: 20, color: itemColor),
          child: icon,
        ),
        label: Text(label, style: labelStyle?.copyWith(color: itemColor)),
      );
    }

    // The swipeable row this menu belongs to (null outside one).
    final swipeTile = context
        .findAncestorStateOfType<MechanixSwipableListTileState>();

    return MechanixMenu<TrackAction>(
      alignment: MechanixMenuAlignment.end,
      // Called after a selection (closeOnSelect) and on an outside tap.
      onClose: () {
        if (swipeTile != null && swipeTile.mounted) swipeTile.close();
      },
      style: const MenuThemeDataConfig(
        borderRadius: BorderRadius.zero,
        regularItemHeight: 64,
      ),
      onSelected: (action) => _onSelected(context, action),
      anchorBuilder: (context, controller, child) {
        return MechanixIconButton.standard(
          key: ValueKey('track_menu_button_${song.path}'),
          type: IconButtonType.rounded,
          size: IconButtonSize.small,
          icon: ImageIcon(
            const AssetImage(MusicIcons.threedotIcon),
            color: theme.colorScheme.onSurface,
          ),
          onPressed: controller.toggle,
        );
      },
      entries: [
        item(
          TrackAction.playNext,
          Image.asset(
            MusicIcons.playlist,
            color: theme.colorScheme.onSurface,
            width: 20,
            height: 20,
          ),
          l10n.playNext,
        ),
        if (showAddToPlaylist)
          item(
            TrackAction.addToPlaylist,
            Image.asset(
              MusicIcons.add,
              color: theme.colorScheme.onSurface,
              width: 20,
              height: 20,
            ),
            l10n.addToPlaylist,
          ),
        item(
          TrackAction.favourite,
          Icon(song.isFavourite ? Icons.star : Icons.star_border),
          song.isFavourite ? l10n.removeFromFavourite : l10n.addToFavourite,
        ),
        if (showSleepTimer)
          item(
            TrackAction.sleepTimer,
            Image.asset(
              MusicIcons.timer,
              color: theme.colorScheme.onSurface,
              width: 20,
              height: 20,
            ),
            l10n.setSleepTimer,
          ),
        if (onRemove != null)
          item(
            TrackAction.remove,
            const Icon(Icons.delete_outline),
            l10n.remove,
            color: theme.colorScheme.error,
          ),
      ],
    );
  }
}
