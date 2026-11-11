import 'package:flutter/material.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Search bar at the top of the search screen.
///
/// Leading: a back arrow until the field is tapped or has text, then a
/// search icon (the design's "music-search" vs "results"/"recall" states).
/// Trailing X: clears the text, or closes the screen when it is empty.
class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(width: 4),
              ListenableBuilder(
                listenable: Listenable.merge([focusNode, controller]),
                builder: (context, _) {
                  final editing =
                      focusNode.hasFocus || controller.text.isNotEmpty;
                  if (editing) {
                    return SizedBox(
                      width: 48,
                      child: Center(
                        child: ImageIcon(
                          const AssetImage(MusicIcons.searchIcon),
                          key: const ValueKey('search_field_icon'),
                          size: 20,
                          color: mutedColor,
                        ),
                      ),
                    );
                  }
                  return MechanixIconButton.standard(
                    key: const ValueKey('search_back_button'),
                    type: IconButtonType.rounded,
                    size: IconButtonSize.small,
                    icon: ImageIcon(
                      const AssetImage(MusicIcons.backIcon),
                      color: colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  );
                },
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('search_field'),
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: false,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: l10n.searchHint,
                    hintStyle: theme.textTheme.titleMedium?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
              MechanixIconButton.standard(
                key: const ValueKey('search_close_button'),
                type: IconButtonType.rounded,
                size: IconButtonSize.small,
                icon: ImageIcon(
                  const AssetImage(MusicIcons.closeIcon),
                  color: colorScheme.onSurface,
                ),
                onPressed: onClose,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
      ],
    );
  }
}
