import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

String songSortLabel(AppLocalizations l10n, SongSort sort) => switch (sort) {
  SongSort.title => l10n.sortTitle,
  SongSort.artist => l10n.sortArtist,
  SongSort.dateAdded => l10n.sortDateAdded,
  SongSort.duration => l10n.sortDuration,
};

/// Opens the All tracks sort sheet.
Future<void> showSortTracksSheet(BuildContext context) {
  final bloc = context.read<SongBloc>();
  return MechanixBottomSheet.showModal<void>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        BlocProvider.value(value: bloc, child: const SortTracksSheet()),
  );
}

class SortTracksSheet extends StatelessWidget {
  const SortTracksSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bloc = context.read<SongBloc>();
    final sort = context.select((SongBloc b) => b.sort);

    TextStyle labelStyle(bool selected) => theme.textTheme.titleLarge!.copyWith(
      color: selected
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
    const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 4);

    void pick(SongSort option) {
      bloc.add(SongSortChanged(option));
      Navigator.of(context).pop();
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Text(
              l10n.sortBy,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          for (final option in SongSort.values)
            MechanixListTile(
              key: ValueKey('sort_tracks_${option.name}'),
              contentPadding: padding,
              leadingWidgets: [
                MechanixRadio<SongSort>(
                  value: option,
                  groupValue: sort,
                  onChanged: (_) => pick(option),
                ),
              ],
              label: Text(
                songSortLabel(l10n, option),
                style: labelStyle(option == sort),
              ),
              onTap: () => pick(option),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
