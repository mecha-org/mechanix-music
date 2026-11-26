import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/playlists_view.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/presentation/screens/search_screen.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_view.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/audio_output_sheet.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_bottom_bar.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/all_tracks_view.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  MusicTab _currentTab = MusicTab.player;

  static const List<Widget> _tabs = [
    NowPlayingLanding(),
    AllTracksView(),
    PlaylistsView(),
  ];

  String _title(AppLocalizations l10n) => switch (_currentTab) {
    MusicTab.player => l10n.appTitle,
    MusicTab.allTracks => l10n.allTracks,
    MusicTab.playlist => l10n.playlists,
  };

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    final searchButton = MechanixIconButton.standard(
      key: const ValueKey('music_search_button'),
      type: IconButtonType.rounded,
      size: IconButtonSize.small,
      icon: ImageIcon(
        const AssetImage(MusicIcons.searchIcon),
        color: theme.colorScheme.onSurface,
      ),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
    );

    // All tracks uses the small app bar. Its folder button opens the file
    // browser, which is where songs are imported into the library.
    if (_currentTab == MusicTab.allTracks) {
      return MechanixAppBar.small(
        primary: false,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        title: Text(l10n.allTracks, key: const ValueKey('music_app_bar_title')),
        titleTextStyle: theme.textTheme.headlineSmall!.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
        actions: [searchButton],
      );
    }

    // Playlists: large title with only search.
    if (_currentTab == MusicTab.playlist) {
      return MechanixAppBar.largeIcon(
        primary: false,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        title: Text(
          _title(l10n).toUpperCase(),
          key: const ValueKey('music_app_bar_title'),
        ),
        actions: [searchButton],
      );
    }

    return MechanixAppBar.largeIcon(
      primary: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      title: Text(
        _title(l10n).toUpperCase(),
        key: const ValueKey('music_app_bar_title'),
      ),
      actions: [
        MechanixIconButton.standard(
          key: const ValueKey('music_cast_button'),
          type: IconButtonType.rounded,
          size: IconButtonSize.small,
          icon: ImageIcon(
            const AssetImage(MusicIcons.audiocastIcon),
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => showAudioOutputSheet(context),
        ),
        searchButton,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocListener<PlaybackBloc, PlaybackState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == PlaybackStatus.failure,
      listener: (context, state) {
        if (state.errorType != null) {
          final message = switch (state.errorType!) {
            PlaybackErrorType.fileDeleted => l10n.errorPlaybackFileDeleted,
            PlaybackErrorType.unknown => l10n.errorPlaybackUnknown,
          };

          MechanixSnackbar.text(
            position: MechanixSnackbarPosition.top,
            text: message,
          ).show(context);
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        appBar: _buildAppBar(context, l10n),
        body: IndexedStack(index: _currentTab.index, children: _tabs),
        bottomNavigationBar: MusicBottomBar(
          currentTab: _currentTab,
          onTabSelected: (tab) => setState(() => _currentTab = tab),
        ),
      ),
    );
  }
}
