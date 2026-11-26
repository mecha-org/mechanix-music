import 'package:flutter/material.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// "RECENT" label with a trash button that clears the recent searches.
class SearchRecentHeader extends StatelessWidget {
  const SearchRecentHeader({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.recent.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: mutedColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          MechanixIconButton.standard(
            key: const ValueKey('search_recent_clear'),
            type: IconButtonType.rounded,
            size: IconButtonSize.small,
            icon: Icon(Icons.delete_outline, size: 20, color: mutedColor),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
