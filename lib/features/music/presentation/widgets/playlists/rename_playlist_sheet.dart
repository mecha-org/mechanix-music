import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Bottom sheet to rename [playlist].
Future<void> showRenamePlaylistSheet(BuildContext context, Playlist playlist) {
  final bloc = context.read<PlaylistBloc>();
  return MechanixBottomSheet.showModal<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => RenamePlaylistSheet(
      initialName: playlist.name,
      onSave: (name) => bloc.add(PlaylistRenamed(playlist.id, name)),
    ),
  );
}

class RenamePlaylistSheet extends StatefulWidget {
  const RenamePlaylistSheet({
    super.key,
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final ValueChanged<String> onSave;

  @override
  State<RenamePlaylistSheet> createState() => _RenamePlaylistSheetState();
}

class _RenamePlaylistSheetState extends State<RenamePlaylistSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    if (name != widget.initialName) widget.onSave(name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final isValid = value.text.trim().isNotEmpty;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    MechanixIconButton.standard(
                      key: const ValueKey('rename_playlist_back'),
                      type: IconButtonType.rounded,
                      icon: Image.asset(
                        MusicIcons.backIcon,
                        color: theme.colorScheme.onSurface,
                        width: 24,
                        height: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.renamePlaylist,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    MechanixIconButton.standard(
                      key: const ValueKey('rename_playlist_save'),
                      type: IconButtonType.rounded,
                      icon: Image.asset(
                        MusicIcons.check,
                        color: theme.colorScheme.onSurface,
                        width: 24,
                        height: 24,
                      ),
                      onPressed: isValid ? _save : null,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                  child: MechanixTextField.outlined(
                    key: const ValueKey('rename_playlist_field'),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    controller: _controller,
                    autofocus: true,
                    hintText: l10n.playlistName,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
