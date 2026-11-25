import 'package:flutter/material.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Asks to confirm deleting the playlist [playlistName]. Completes with
/// true when the user taps Delete.
Future<bool?> showDeletePlaylistConfirmationSheet(
  BuildContext context,
  String playlistName,
) {
  return MechanixBottomSheet.showModal<bool>(
    context: context,
    builder: (_) =>
        DeletePlaylistConfirmationSheet(playlistName: playlistName),
  );
}

class DeletePlaylistConfirmationSheet extends StatelessWidget {
  const DeletePlaylistConfirmationSheet({
    super.key,
    required this.playlistName,
  });

  final String playlistName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final style = TextStyle(
      fontFamily: MechanixFontFamily.geist,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      color: colorScheme.onSurface,
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.deletePlaylistQuestion(playlistName),
                key: const ValueKey('delete_playlist_question'),
                style: style,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: MechanixButton.outline(
                      key: const ValueKey('delete_playlist_cancel_button'),
                      size: ButtonSize.large,
                      icon: Image.asset(
                        MusicIcons.closeIcon,
                        width: 32,
                        height: 32,
                        color: colorScheme.onSurface,
                      ),
                      labelText: Text(
                        l10n.cancel.toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      widthSizing: ButtonLayoutSizing.fill,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MechanixButton.filled(
                      key: const ValueKey('delete_playlist_delete_button'),
                      size: ButtonSize.large,
                      icon: Image.asset(
                        MusicIcons.delete,
                        width: 32,
                        height: 32,
                        color: colorScheme.error,
                      ),
                      labelText: Text(
                        l10n.delete.toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      widthSizing: ButtonLayoutSizing.fill,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      foregroundColor: colorScheme.error,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
