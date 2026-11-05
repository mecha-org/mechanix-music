import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_event.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_state.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';

export 'playlist_event.dart';
export 'playlist_state.dart';

/// Playlists for the Playlist tab and playlist screens.
///
/// Edits (rename, add, remove, reorder) update the state right away and are
/// then saved, so lists do not flicker while the .m3u8 files are written.
class PlaylistBloc extends Bloc<PlaylistEvent, PlaylistState> {
  PlaylistBloc({required PlaylistRepository repository})
    : _repository = repository,
      super(const PlaylistState()) {
    on<PlaylistsRequested>(_onRequested);
    on<PlaylistCreateRequested>(_onCreate);
    on<PlaylistRenamed>(_onRenamed);
    on<PlaylistSongAdded>(_onSongAdded);
    on<PlaylistSongRemoved>(_onSongRemoved);
    on<PlaylistSongMoved>(_onSongMoved);

    // Favourites also change from the track menus: reload to show them.
    _changesSub = _repository.onChanged.listen(
      (_) => add(const PlaylistsRequested()),
    );
  }

  final PlaylistRepository _repository;
  StreamSubscription<void>? _changesSub;

  @override
  Future<void> close() async {
    await _changesSub?.cancel();
    return super.close();
  }

  Future<void> _onRequested(
    PlaylistsRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    try {
      final models = await _repository.getPlaylists();
      emit(
        PlaylistState(
          isLoading: false,
          playlists: models.map(Playlist.fromModel).toList(),
        ),
      );
    } catch (e) {
      AppLogger.e('[PlaylistBloc] Loading playlists failed: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  /// "Playlist N" with the smallest N not used yet.
  String _nextDefaultName() {
    final names = state.playlists.map((p) => p.name.toLowerCase()).toSet();
    var n = 1;
    while (names.contains('playlist $n')) {
      n++;
    }
    return 'Playlist $n';
  }

  Future<void> _onCreate(
    PlaylistCreateRequested event,
    Emitter<PlaylistState> emit,
  ) async {
    try {
      final created = Playlist.fromModel(
        await _repository.createPlaylist(_nextDefaultName()),
      );
      emit(
        state.copyWith(
          isLoading: false,
          playlists: [
            ...state.playlists.where((p) => p.id != created.id),
            created,
          ],
        ),
      );
      event.created?.complete(created);
    } catch (e) {
      AppLogger.e('[PlaylistBloc] Creating a playlist failed: $e');
      event.created?.completeError(e);
    }
  }

  /// Replaces the playlist with [id] in the state, then runs [save].
  Future<void> _update(
    String id,
    Emitter<PlaylistState> emit,
    Playlist Function(Playlist) change,
    Future<void> Function(Playlist) save,
  ) async {
    final current = state.byId(id);
    if (current == null) return;
    final updated = change(current);
    if (updated == current) return;

    emit(
      state.copyWith(
        playlists: [
          for (final p in state.playlists) p.id == id ? updated : p,
        ],
      ),
    );
    try {
      await save(updated);
    } catch (e) {
      AppLogger.e('[PlaylistBloc] Saving playlist $id failed: $e');
      add(const PlaylistsRequested()); // back to what is stored
    }
  }

  Future<void> _onRenamed(PlaylistRenamed event, Emitter<PlaylistState> emit) {
    final name = event.name.trim();
    // Favourites (a fixed playlist) keeps its name.
    if (name.isEmpty || (state.byId(event.playlistId)?.isFixed ?? true)) {
      return Future.value();
    }
    return _update(
      event.playlistId,
      emit,
      (p) => p.copyWith(name: name),
      (p) => _repository.renamePlaylist(p.id, p.name),
    );
  }

  Future<void> _onSongAdded(
    PlaylistSongAdded event,
    Emitter<PlaylistState> emit,
  ) => _update(
    event.playlistId,
    emit,
    (p) => p.songPaths.contains(event.songPath)
        ? p
        : p.copyWith(songPaths: [...p.songPaths, event.songPath]),
    (p) => _repository.setPlaylistSongs(p.id, p.songPaths),
  );

  Future<void> _onSongRemoved(
    PlaylistSongRemoved event,
    Emitter<PlaylistState> emit,
  ) => _update(
    event.playlistId,
    emit,
    (p) => p.copyWith(
      songPaths: p.songPaths.where((s) => s != event.songPath).toList(),
    ),
    (p) => _repository.setPlaylistSongs(p.id, p.songPaths),
  );

  Future<void> _onSongMoved(
    PlaylistSongMoved event,
    Emitter<PlaylistState> emit,
  ) => _update(
    event.playlistId,
    emit,
    (p) {
      final paths = [...p.songPaths];
      if (event.oldIndex < 0 || event.oldIndex >= paths.length) return p;
      var newIndex = event.newIndex;
      if (newIndex > event.oldIndex) newIndex -= 1;
      final moved = paths.removeAt(event.oldIndex);
      paths.insert(newIndex.clamp(0, paths.length), moved);
      return p.copyWith(songPaths: paths);
    },
    (p) => _repository.setPlaylistSongs(p.id, p.songPaths),
  );
}
