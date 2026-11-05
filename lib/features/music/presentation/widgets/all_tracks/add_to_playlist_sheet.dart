import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Opens the "Add to playlist" sheet for [song]. The song ends up in exactly
/// the playlists that are checked when the user taps Save.
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  SongModel song,
) async {
  // Looked up before the sheet opens: [context] may be a swiped row's ⋮
  // button, which is gone once the row closes.
  final repository = context.read<PlaylistRepository>();
  final playlistBloc = context.read<PlaylistBloc>();

  await MechanixBottomSheet.showModal<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => AddToPlaylistSheet(song: song, repository: repository),
  );

  // The sheet may have created playlists too, so always refresh.
  if (!playlistBloc.isClosed) {
    playlistBloc.add(const PlaylistsRequested());
  }
}

class AddToPlaylistSheet extends StatefulWidget {
  const AddToPlaylistSheet({
    super.key,
    required this.song,
    required this.repository,
  });

  final SongModel song;
  final PlaylistRepository repository;

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  List<PlaylistModel>? _playlists;
  Set<String> _selected = {};
  bool _creating = false;
  bool _saving = false;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Favourites has its own menu option, so only user playlists are listed.
    final playlists = [
      for (final playlist in await widget.repository.getPlaylists())
        if (!playlist.isFixed) playlist,
    ];
    if (!mounted) return;
    setState(() {
      _playlists = playlists;
      _selected = {
        for (final playlist in playlists)
          if (playlist.songPaths.contains(widget.song.path)) playlist.id,
      };
    });
  }

  void _toggle(PlaylistModel playlist) {
    setState(() {
      if (!_selected.remove(playlist.id)) _selected.add(playlist.id);
    });
  }

  Future<void> _createPlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final playlist = await widget.repository.createPlaylist(name);
    if (!mounted) return;
    setState(() {
      final playlists = _playlists ?? [];
      if (!playlists.any((p) => p.id == playlist.id)) {
        _playlists = [...playlists, playlist];
      }
      // A new playlist is created to add this song to it.
      _selected.add(playlist.id);
      _creating = false;
      _nameController.clear();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repository.setSongPlaylists(widget.song.path, _selected);
    if (!mounted) return;
    // Shown from the sheet: it goes to the root overlay, so it stays after
    // the sheet closes.
    MechanixSnackbar.text(
      position: MechanixSnackbarPosition.top,
      text: AppLocalizations.of(context)!.playlistsUpdated,
    ).show(context);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final playlists = _playlists;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Text(
              l10n.addToPlaylist,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Flexible(
            child: playlists == null
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      if (playlists.isEmpty && !_creating)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Text(
                            l10n.noPlaylists,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      for (final playlist in playlists)
                        _PlaylistRow(
                          playlist: playlist,
                          selected: _selected.contains(playlist.id),
                          onToggle: () => _toggle(playlist),
                        ),
                      if (_creating)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: MechanixTextField.outlined(
                                  key: const ValueKey('new_playlist_field'),
                                  controller: _nameController,
                                  autofocus: true,
                                  hintText: l10n.playlistName,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _createPlaylist(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MechanixIconButton.standard(
                                key: const ValueKey('new_playlist_confirm'),
                                type: IconButtonType.rounded,
                                icon: const Icon(Icons.check),
                                onPressed: _createPlaylist,
                              ),
                            ],
                          ),
                        )
                      else
                        MechanixListTile(
                          key: const ValueKey('new_playlist_tile'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leadingWidgets: [
                            Icon(Icons.add, color: theme.colorScheme.onSurface),
                          ],
                          labelText: l10n.newPlaylist,
                          onTap: () => setState(() => _creating = true),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: MechanixButton.outline(
                    size: ButtonSize.large,
                    key: const ValueKey('add_to_playlist_cancel'),
                    labelText: Text(
                      l10n.cancel.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    icon: Image.asset(
                      MusicIcons.closeIcon,
                      width: 32,
                      height: 32,
                      color: theme.colorScheme.onSurface,
                    ),
                    widthSizing: ButtonLayoutSizing.fill,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                Expanded(
                  child: MechanixButton.filled(
                    size: ButtonSize.large,
                    key: const ValueKey('add_to_playlist_save'),
                    labelText: Text(
                      l10n.save.toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    icon: Icons.check,
                    widthSizing: ButtonLayoutSizing.fill,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurface,
                    onPressed: playlists == null || _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.selected,
    required this.onToggle,
  });

  final PlaylistModel playlist;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return MechanixListTile(
      key: ValueKey('playlist_row_${playlist.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leadingWidgets: [
        Container(
          width: 40,
          height: 40,
          color: colorScheme.onSurface.withValues(alpha: 0.9),
          child: Center(
            child: ImageIcon(
              const AssetImage(MusicIcons.musicIcon),
              size: 18,
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
      ],
      labelText: playlist.name,
      supportingText: l10n.tracksCount(
        playlist.trackCount.toString().padLeft(2, '0'),
      ),
      trailingWidgets: [
        MechanixCheckbox(value: selected, onChanged: (_) => onToggle()),
      ],
      onTap: onToggle,
    );
  }
}
