import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Label of a sleep timer option ("5 minutes", "End of track").
String sleepTimerLabel(AppLocalizations l10n, SleepTimerOption option) {
  final duration = option.duration;
  return duration == null
      ? l10n.endOfTrack
      : l10n.minutesCount(duration.inMinutes);
}

/// Opens the "Set sleep timer" sheet. Picking an option starts the timer
/// and closes the sheet; picking the active option again turns it off.
Future<void> showSleepTimerSheet(BuildContext context) async {
  // Looked up before the sheet opens: [context] may be a swiped row's ⋮
  // button, which is gone once the row closes.
  final bloc = context.read<PlaybackBloc>();
  final picked = await MechanixBottomSheet.showModal<_SleepTimerChoice>(
    context: context,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const SleepTimerSheet(),
    ),
  );
  // Set the timer even if [context] is gone by now.
  if (picked == null || bloc.isClosed) return;
  bloc.add(PlaybackSetSleepTimer(picked.option));
}

/// Result of the sheet; [option] null means "turn the timer off".
class _SleepTimerChoice {
  const _SleepTimerChoice(this.option);
  final SleepTimerOption? option;
}

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BlocSelector<PlaybackBloc, PlaybackState, SleepTimerOption?>(
      selector: (state) => state.sleepTimer,
      builder: (context, active) {
        void pick(SleepTimerOption option) {
          final chosen = option == active ? null : option;
          // Shown from the sheet: it goes to the root overlay, so it stays
          // after the sheet closes.
          MechanixSnackbar.text(
            position: MechanixSnackbarPosition.top,
            text: chosen == null
                ? l10n.sleepTimerOff
                : l10n.sleepTimerSet(sleepTimerLabel(l10n, chosen)),
          ).show(context);
          Navigator.of(context).pop(_SleepTimerChoice(chosen));
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.setSleepTimer,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              for (final option in SleepTimerOption.values)
                MechanixListTile(
                  key: ValueKey('sleep_timer_${option.name}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  leadingWidgets: [
                    MechanixRadio<SleepTimerOption>(
                      value: option,
                      groupValue: active,
                      toggleable: true,
                      onChanged: (_) => pick(option),
                    ),
                  ],
                  labelText: sleepTimerLabel(l10n, option),
                  onTap: () => pick(option),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
