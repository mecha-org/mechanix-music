import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:widgets/widgets.dart';

/// Repeat, previous, play/pause, next and shuffle buttons.
class LandingControls extends StatelessWidget {
  const LandingControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlaybackBloc, PlaybackState, _ControlsData>(
      selector: _ControlsData.fromState,
      builder: (context, data) {
        final bloc = context.read<PlaybackBloc>();
        final colorScheme = Theme.of(context).colorScheme;
        final hasSong = data.hasSong;

        // Colours from the design. Active (something to play): white icons,
        // dark filled previous/next with a grey border and an orange play
        // button. Inactive (empty state or nothing to go to): grey icons,
        // transparent previous/next and a dark grey play button.
        final activeIcon = colorScheme.onSurface;
        final inactiveIcon = colorScheme.onSurfaceVariant;
        final selectedIcon = colorScheme.primary;

        // The button draws a disabled border at 38% opacity, so a lighter
        // colour is passed then; it ends up as the design's outline grey.
        Color border(bool enabled) =>
            enabled ? colorScheme.outline : colorScheme.onSecondaryFixed;
        final canPrevious = hasSong && data.hasPrevious;
        final canNext = hasSong && data.hasNext;

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              MechanixIconButton.standard(
                key: const ValueKey('landing_repeat_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.small,
                isSelected: data.repeatMode != RepeatMode.off,
                backgroundColor: Colors.transparent,
                foregroundColor: activeIcon,
                disabledColor: Colors.transparent,
                disabledForegroundColor: inactiveIcon,
                selectedBackgroundColor: Colors.transparent,
                selectedForegroundColor: selectedIcon,
                icon: Badge(
                  isLabelVisible: data.repeatMode == RepeatMode.one,
                  backgroundColor: colorScheme.primary,
                  textColor: colorScheme.onPrimary,
                  label: const Text('1'),
                  child: const ImageIcon(AssetImage(MusicIcons.repeatIcon)),
                ),
                onPressed: hasSong
                    ? () => bloc.add(const PlaybackCycleRepeatMode())
                    : null,
              ),
              MechanixIconButton.outline(
                key: const ValueKey('landing_previous_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.medium,
                backgroundColor: colorScheme.surfaceContainerLow,
                foregroundColor: activeIcon,
                borderColor: border(canPrevious),
                borderWidth: 1,
                disabledColor: Colors.transparent,
                disabledForegroundColor: inactiveIcon,
                icon: const ImageIcon(AssetImage(MusicIcons.previousIcon)),
                onPressed: canPrevious
                    ? () => bloc.add(const PlaybackPlayPrevious())
                    : null,
              ),
              MechanixIconButton.filled(
                key: const ValueKey('landing_play_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.large,
                // Empty state ("Start playing…"): looks inactive as in the
                // design, but a tap still starts the Playing next queue.
                backgroundColor: hasSong
                    ? colorScheme.primary
                    : colorScheme.surfaceContainer,
                foregroundColor: hasSong ? activeIcon : inactiveIcon,
                disabledColor: colorScheme.surfaceContainer,
                disabledForegroundColor: inactiveIcon,
                icon: ImageIcon(
                  AssetImage(
                    data.isPlaying
                        ? MusicIcons.pauseIcon
                        : MusicIcons.resumeIcon,
                  ),
                ),
                onPressed: _playPauseAction(bloc, data),
              ),
              MechanixIconButton.outline(
                key: const ValueKey('landing_next_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.medium,
                backgroundColor: colorScheme.surfaceContainerLow,
                foregroundColor: activeIcon,
                borderColor: border(canNext),
                borderWidth: 1,
                disabledColor: Colors.transparent,
                disabledForegroundColor: inactiveIcon,
                icon: const ImageIcon(AssetImage(MusicIcons.nextIcon)),
                onPressed: canNext
                    ? () => bloc.add(const PlaybackPlayNext())
                    : null,
              ),
              MechanixIconButton.standard(
                key: const ValueKey('landing_shuffle_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.small,
                isSelected: data.isShuffled,
                backgroundColor: Colors.transparent,
                foregroundColor: activeIcon,
                disabledColor: Colors.transparent,
                disabledForegroundColor: inactiveIcon,
                selectedBackgroundColor: Colors.transparent,
                selectedForegroundColor: selectedIcon,
                icon: const ImageIcon(AssetImage(MusicIcons.shuffleIcon)),
                onPressed: hasSong
                    ? () => bloc.add(const PlaybackToggleShuffle())
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Pause/resume the current song, or start the queue when nothing is
  /// playing yet. Disabled when there is nothing to play.
  VoidCallback? _playPauseAction(PlaybackBloc bloc, _ControlsData data) {
    if (data.isPlaying) return () => bloc.add(const PlaybackPause());
    if (data.hasSong) return () => bloc.add(const PlaybackResume());
    final first = bloc.state.upNext.firstOrNull;
    if (first == null) return null;
    return () => bloc.add(PlaybackPlay(first));
  }
}

/// What the control buttons depend on, so they only rebuild when it changes
/// (not on every list or duration update).
class _ControlsData {
  const _ControlsData({
    required this.hasSong,
    required this.canStart,
    required this.isPlaying,
    required this.hasNext,
    required this.hasPrevious,
    required this.repeatMode,
    required this.isShuffled,
  });

  factory _ControlsData.fromState(PlaybackState state) => _ControlsData(
    hasSong: state.song != null,
    canStart: state.playOrder.isNotEmpty,
    isPlaying:
        state.status == PlaybackStatus.playing ||
        state.status == PlaybackStatus.loading,
    hasNext: state.hasNext,
    hasPrevious: state.hasPrevious,
    repeatMode: state.repeatMode,
    isShuffled: state.isShuffled,
  );

  final bool hasSong;
  final bool canStart;
  final bool isPlaying;
  final bool hasNext;
  final bool hasPrevious;
  final RepeatMode repeatMode;
  final bool isShuffled;

  @override
  bool operator ==(Object other) =>
      other is _ControlsData &&
      other.hasSong == hasSong &&
      other.canStart == canStart &&
      other.isPlaying == isPlaying &&
      other.hasNext == hasNext &&
      other.hasPrevious == hasPrevious &&
      other.repeatMode == repeatMode &&
      other.isShuffled == isShuffled;

  @override
  int get hashCode => Object.hash(
    hasSong,
    canStart,
    isPlaying,
    hasNext,
    hasPrevious,
    repeatMode,
    isShuffled,
  );
}
