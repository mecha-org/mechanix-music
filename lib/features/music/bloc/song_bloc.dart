import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';

class SongBloc extends Bloc<SongEvent, SongState> {
  final SongRepository songRepository;

  SongSort _sort = SongSort.title;

  /// Bumped on reload; drops pages of the old list.
  int _generation = 0;

  /// Last songs tried as the next page's cursor.
  static const _cursorTries = 3;
  StreamSubscription<SongChange>? _songChangedSub;

  SongSort get sort => _sort;

  SongBloc({required this.songRepository}) : super(const SongInitial()) {
    on<SongInitialized>(_onSongInitialized);
    on<SongLoadMore>(_onSongLoadMore);
    on<SongUpsert>(_onSongUpsert);
    on<SongDelete>(_onSongDelete);
    on<SongAddByPaths>(_onSongAddByPaths);
    on<SongSyncCompleted>(_onSongSyncCompleted);
    on<SongToggleFavourite>(_onSongToggleFavourite);
    on<SongSortChanged>(_onSortChanged);

    _songChangedSub = songRepository.onSongChanged.listen((change) {
      switch (change.type) {
        case SongChangeType.upsert:
          add(SongUpsert(change.song));
        case SongChangeType.delete:
          add(SongDelete(change.song));
      }
    });
  }

  @override
  Future<void> close() {
    _songChangedSub?.cancel();
    return super.close();
  }

  Future<void> _onSongInitialized(
    SongInitialized event,
    Emitter<SongState> emit,
  ) async {
    emit(const SongLoading());
    _generation++;

    // Load first page immediately from cache
    try {
      AppLogger.i('[SongBloc] Loading first page from cache');
      await _fetchPage(emit);
    } catch (e) {
      AppLogger.e('[SongBloc] Loading first page failed: $e');
      emit(const SongError(SongErrorType.loadFailed));
      return;
    }

    // Run sync in the background
    unawaited(
      songRepository
          .syncInitialSongLibrary()
          .then((changesDetected) {
            AppLogger.i(
              '[SongBloc] Background sync completed (changesDetected: $changesDetected)',
            );
            final isEmpty =
                state is SongLoaded && (state as SongLoaded).songs.isEmpty;
            if (changesDetected || isEmpty) {
              add(const SongSyncCompleted());
            }
          })
          .catchError((e) {
            AppLogger.e('[SongBloc] Background sync failed: $e');
          }),
    );
  }

  Future<void> _onSongSyncCompleted(
    SongSyncCompleted event,
    Emitter<SongState> emit,
  ) async {
    AppLogger.i('[SongBloc] Reloading first page after sync completed');
    await _reload(emit);
  }

  Future<void> _onSortChanged(
    SongSortChanged event,
    Emitter<SongState> emit,
  ) async {
    if (event.sort == _sort) return;
    _sort = event.sort;
    await _reload(emit, showSort: true);
  }

  /// Reloads the first page; [showSort] shows the new sort at once.
  Future<void> _reload(
    Emitter<SongState> emit, {
    bool showSort = false,
  }) async {
    _generation++;
    if (state case final SongLoaded current when showSort) {
      // No more pages of the old order.
      emit(
        _loaded(
          current.songs,
          hasMore: false,
          totalCount: current.totalCount,
        ),
      );
    }
    try {
      await _fetchPage(emit);
    } catch (e) {
      AppLogger.e('[SongBloc] Reloading first page failed: $e');
    }
  }

  SongLoaded _loaded(
    List<SongModel> songs, {
    required bool hasMore,
    bool isLoadingMore = false,
    required int totalCount,
  }) => SongLoaded(
    songs: songs,
    hasMore: hasMore,
    isLoadingMore: isLoadingMore,
    sort: _sort,
    totalCount: totalCount,
  );

  Future<void> _onSongLoadMore(
    SongLoadMore event,
    Emitter<SongState> emit,
  ) async {
    try {
      final current = state;
      if (current is! SongLoaded || !current.hasMore || current.isLoadingMore) {
        return;
      }

      final previousSongs = current.songs;
      emit(current.copyWith(isLoadingMore: true));

      await _fetchPage(emit, previousSongs: previousSongs);
    } catch (e) {
      AppLogger.e('[SongBloc] SongLoadMore failed: $e');
      emit(const SongError(SongErrorType.loadFailed));
    }
  }

  /// Puts the song at its place in the list.
  Future<void> _onSongUpsert(
    SongUpsert event,
    Emitter<SongState> emit,
  ) async {
    final current = state;
    if (current is! SongLoaded) return;

    final song = event.song;
    final songs = List<SongModel>.from(current.songs);
    final index = songs.indexWhere((s) => s.path == song.path);
    final old = index == -1 ? null : songs.removeAt(index);

    final at = _placeOf(
      song,
      songs,
      old: old,
      oldIndex: index,
      hasMore: current.hasMore,
    );
    if (at != null) songs.insert(at, song);
    final shown = at != null;

    AppLogger.i(
      shown
          ? '[SongBloc] Updated in state: ${song.path}'
          : '[SongBloc] Left for a later page: ${song.path}',
    );
    emit(current.copyWith(songs: songs));
    await _refreshTotal(emit);
  }

  /// Index for [song] in [songs]: its old place if it still fits, else by
  /// sort order; null when a later page brings it.
  int? _placeOf(
    SongModel song,
    List<SongModel> songs, {
    SongModel? old,
    required int oldIndex,
    required bool hasMore,
  }) {
    if (old != null &&
        _keepsPlace(songs, oldIndex, song, old, hasMore: hasMore)) {
      return oldIndex;
    }
    final before = songs.indexWhere((s) => compareSongs(_sort, song, s) < 0);
    if (before != -1) return before;
    return hasMore ? null : songs.length;
  }

  /// Whether [song] still fits at [index]. As the last loaded song it must
  /// not sort later than [old]: the next page starts after it.
  bool _keepsPlace(
    List<SongModel> songs,
    int index,
    SongModel song,
    SongModel old, {
    required bool hasMore,
  }) {
    bool inOrder(SongModel a, SongModel b) => compareSongs(_sort, a, b) <= 0;
    if (index > 0 && !inOrder(songs[index - 1], song)) return false;
    if (index < songs.length) return inOrder(song, songs[index]);
    return !hasMore || inOrder(song, old);
  }

  Future<void> _onSongDelete(
    SongDelete event,
    Emitter<SongState> emit,
  ) async {
    final current = state;
    if (current is! SongLoaded) return;

    final songs = List<SongModel>.from(current.songs);
    final index = songs.indexWhere((s) => s.path == event.song.path);
    if (index != -1) {
      songs.removeAt(index);
      AppLogger.i('[SongBloc] Removed from state: ${event.song.path}');
      emit(current.copyWith(songs: songs));
    }
    await _refreshTotal(emit);
  }

  /// Reads the library size again.
  Future<void> _refreshTotal(Emitter<SongState> emit) async {
    final int totalCount;
    try {
      totalCount = await songRepository.getSongCount();
    } catch (e) {
      AppLogger.e('[SongBloc] getSongCount failed: $e');
      return;
    }
    if (state case final SongLoaded current) {
      emit(current.copyWith(totalCount: totalCount));
    }
  }

  Future<void> _onSongAddByPaths(
    SongAddByPaths event,
    Emitter<SongState> emit,
  ) async {
    try {
      if (event.paths.isEmpty) return;

      AppLogger.i('[SongBloc] Adding ${event.paths.length} song(s) by path');

      await songRepository.addSongsByPaths(event.paths);
      AppLogger.i('[SongBloc] SongAddByPaths completed');
    } catch (e) {
      AppLogger.e('[SongBloc] SongAddByPaths failed: $e');
    }
  }

  /// The list updates through [SongRepository.onSongChanged] (upsert).
  Future<void> _onSongToggleFavourite(
    SongToggleFavourite event,
    Emitter<SongState> emit,
  ) async {
    try {
      await songRepository.setFavourite(
        event.song.path,
        !event.song.isFavourite,
      );
    } catch (e) {
      AppLogger.e('[SongBloc] SongToggleFavourite failed: $e');
    }
  }

  /// The page after [previousSongs]. Falls back to an earlier song when
  /// the last one has just left the index.
  Future<List<SongModel>> _getPageAfter(List<SongModel> previousSongs) async {
    Future<List<SongModel>> after(String? path) => songRepository.getSongs(
      after: path,
      limit: Constants.pageSize,
      sort: _sort,
    );

    if (previousSongs.isEmpty) return after(null);
    final cursors = previousSongs.reversed.take(_cursorTries).toList();
    for (final cursor in cursors.take(cursors.length - 1)) {
      try {
        return await after(cursor.path);
      } catch (e) {
        AppLogger.e('[SongBloc] No page after ${cursor.path}: $e');
      }
    }
    return after(cursors.last.path);
  }

  Future<void> _fetchPage(
    Emitter<SongState> emit, {
    List<SongModel> previousSongs = const [],
  }) async {
    final generation = _generation;
    List<SongModel> page;
    int totalCount;
    try {
      page = await _getPageAfter(previousSongs);
    } catch (e) {
      AppLogger.e('[SongBloc] getSongs failed: $e');
      if (generation == _generation) {
        emit(const SongError(SongErrorType.loadFailed));
      }
      rethrow;
    }
    try {
      totalCount = await songRepository.getSongCount();
    } catch (e) {
      AppLogger.e('[SongBloc] getSongCount failed: $e');
      if (generation == _generation) {
        emit(const SongError(SongErrorType.unknown));
      }
      rethrow;
    }
    // Reloaded meanwhile.
    if (generation != _generation) return;

    final loaded = {for (final song in previousSongs) song.path};
    final songs = [
      ...previousSongs,
      for (final song in page)
        if (!loaded.contains(song.path)) song,
    ];
    final hasMore = page.isNotEmpty && songs.length < totalCount;

    AppLogger.i(
      '[SongBloc] Loaded ${page.length} songs '
      '(${songs.length} / $totalCount, ${_sort.name})',
    );

    emit(_loaded(songs, hasMore: hasMore, totalCount: totalCount));
  }
}
