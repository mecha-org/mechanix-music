import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_artwork.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/audio_output_sheet.dart';
import 'package:widgets/widgets.dart';

class MusicMiniPlayer extends StatelessWidget {
  const MusicMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const MusicScreen())),
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 72,
        color: colorScheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            BlocSelector<PlaybackBloc, PlaybackState, String?>(
              selector: (state) => state.song?.artworkBase64,
              builder: (context, artworkBase64) =>
                  // 40 px ring (4 px) around round artwork, in a 44 px slot.
                  SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: ProgressArtwork(
                        artworkBase64: artworkBase64,
                        size: 40,
                      ),
                    ),
                  ),
            ),
            const SizedBox(width: 12),

            // Song title / artist
            Expanded(
              child:
                  BlocSelector<PlaybackBloc, PlaybackState, (String?, String?)>(
                    selector: (state) =>
                        (state.song?.title, state.song?.artist),
                    builder: (context, songInfo) {
                      final localizations = AppLocalizations.of(context);
                      final title = songInfo.$1 ?? localizations!.nowPlaying;
                      final artist = songInfo.$2 ?? localizations!.unknown;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            artist,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
            ),

            // Audio output (same sheet as the cast button on the Music screen)
            MechanixIconButton.standard(
              key: const ValueKey('mini_player_cast_button'),
              icon: Image.asset(
                MusicIcons.audiocastIcon,
                color: colorScheme.onSurface,
                height: 24,
                width: 24,
              ),
              isSelected: false,
              onPressed: () => showAudioOutputSheet(context),
            ),

            // Play/Pause
            BlocSelector<PlaybackBloc, PlaybackState, bool>(
              selector: (state) =>
                  state.status == PlaybackStatus.playing ||
                  state.status == PlaybackStatus.loading,
              builder: (context, isPlaying) => MechanixIconButton.standard(
                icon: Image.asset(
                  isPlaying ? MusicIcons.pauseIcon : MusicIcons.resumeIcon,
                  color: colorScheme.onSurface,
                  height: isPlaying ? 20 : 24,
                  width: isPlaying ? 20 : 24,
                ),
                isSelected: false,
                onPressed: () => context.read<PlaybackBloc>().add(
                  isPlaying ? const PlaybackPause() : const PlaybackResume(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
