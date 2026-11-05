import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_mini_player.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Bottom-navigation tabs, in display order.
enum MusicTab { player, allTracks, playlist }

/// Bottom navigation (Player / All tracks / Playlist), with the mini player
/// above it on tabs other than Player while a song is loaded.
class MusicBottomBar extends StatelessWidget {
  const MusicBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  final MusicTab currentTab;
  final ValueChanged<MusicTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Player tab already shows the full player.
        if (currentTab != MusicTab.player)
          BlocSelector<PlaybackBloc, PlaybackState, bool>(
            selector: (state) => state.song != null,
            builder: (context, hasSong) {
              return hasSong
                  ? const MusicMiniPlayer()
                  : const SizedBox.shrink();
            },
          ),
        MechanixNavigationBar(
          key: const ValueKey('music_navigation_bar'),
          selectedIndex: currentTab.index,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 56,
          onDestinationSelected: (index) =>
              onTabSelected(MusicTab.values[index]),
          destinations: [
            MechanixNavigationDestination(
              icon: const ImageIcon(AssetImage(MusicIcons.musicDisc)),
              label: l10n.nowPlaying,
            ),
            MechanixNavigationDestination(
              icon: const ImageIcon(AssetImage(MusicIcons.musicNote)),
              label: l10n.allTracks,
            ),
            MechanixNavigationDestination(
              icon: const ImageIcon(AssetImage(MusicIcons.playlist)),
              label: l10n.playlist,
            ),
          ],
        ),
      ],
    );
  }
}
