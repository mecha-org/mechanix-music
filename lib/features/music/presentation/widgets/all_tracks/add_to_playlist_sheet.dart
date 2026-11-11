import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/icons.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:widgets/widgets.dart';

/// Opens the "Add to playlist" sheet for [song]. All boxes start unticked;
/// Save adds the song to the ticked playlists (it is never removed here).
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
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
  final Set<String> _selected = {};
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
    // Every box starts unticked: ticking a playlist adds the song to it.
    setState(() => _playlists = playlists);
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
    // Only adds: the song stays in the playlists it is already in (their
    // boxes start unticked, so they are not a request to remove it).
    final path = widget.song.path;
    await widget.repository.setSongPlaylists(path, {
      ..._selected,
      for (final playlist in _playlists ?? const <PlaylistModel>[])
        if (playlist.songPaths.contains(path)) playlist.id,
    });
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
          // Spacing measured from the design.
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 40, 20, 18),
            child: Text(
              l10n.addToPlaylist,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Flexible(
            // Lets the list be dragged with the mouse too (a mouse wheel
            // already scrolls it); it scrolls once it is taller than the
            // space the sheet has.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
              ),
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
                          // Not in the design; kept so a playlist can still
                          // be created from here. Laid out like the rows.
                          InkWell(
                            key: const ValueKey('new_playlist_tile'),
                            onTap: () => setState(() => _creating = true),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                21,
                                21,
                                26,
                                21,
                              ),
                              child: Row(
                                children: [
                                  SizedBox.square(
                                    dimension: 54,
                                    child: Icon(
                                      Icons.add,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Text(
                                    l10n.newPlaylist,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            child: Row(
              spacing: 13,
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

/// A playlist in the sheet, as in the design: 54 px cover, name and
/// track count, and a checkbox on the right. 96 px tall.
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      key: ValueKey('playlist_row_${playlist.id}'),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(21, 21, 26, 21),
        child: Row(
          children: [
            Image.asset(
              MusicIcons.musicIcon,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    l10n.tracksCount(
                      playlist.trackCount.toString().padLeft(2, '0'),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            MechanixCheckbox(value: selected, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }
}
