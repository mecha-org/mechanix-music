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

  int _currentOffset = 0;
  StreamSubscription<SongChange>? _songChangedSub;

  SongBloc({required this.songRepository}) : super(const SongInitial()) {
    on<SongInitialized>(_onSongInitialized);
    on<SongLoadMore>(_onSongLoadMore);
    on<SongUpsert>(_onSongUpsert);
    on<SongDelete>(_onSongDelete);
    on<SongAddByPaths>(_onSongAddByPaths);
    on<SongSyncCompleted>(_onSongSyncCompleted);
    on<SongToggleFavourite>(_onSongToggleFavourite);

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
    _currentOffset = 0;

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
    _currentOffset = 0;
    try {
      AppLogger.i('[SongBloc] Reloading first page after sync completed');
      await _fetchPage(emit);
    } catch (e) {
      AppLogger.e('[SongBloc] Reloading first page failed: $e');
    }
  }

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
      emit(
        SongLoaded(songs: previousSongs, hasMore: true, isLoadingMore: true),
      );

      await _fetchPage(emit, previousSongs: previousSongs);
    } catch (e) {
      AppLogger.e('[SongBloc] SongLoadMore failed: $e');
      emit(const SongError(SongErrorType.loadFailed));
    }
  }

  void _onSongUpsert(SongUpsert event, Emitter<SongState> emit) {
    final current = state;
    if (current is! SongLoaded) return;

    final songs = List<SongModel>.from(current.songs);
    final index = songs.indexWhere((s) => s.path == event.song.path);

    if (index != -1) {
      // Existing song — update in place
      songs[index] = event.song;
      AppLogger.i('[SongBloc] Updated in state: ${event.song.path}');
    } else {
      // New song — insert sorted by title
      songs.add(event.song);
      songs.sort((a, b) => a.title.compareTo(b.title));
      _currentOffset++;
      AppLogger.i('[SongBloc] Inserted in state: ${event.song.path}');
    }

    emit(SongLoaded(songs: songs, hasMore: current.hasMore));
  }

  void _onSongDelete(SongDelete event, Emitter<SongState> emit) {
    final current = state;
    if (current is! SongLoaded) return;

    final songs = List<SongModel>.from(current.songs)
      ..removeWhere((s) => s.path == event.song.path);

    _currentOffset = (_currentOffset - 1).clamp(0, _currentOffset);

    AppLogger.i('[SongBloc] Removed from state: ${event.song.path}');
    emit(SongLoaded(songs: songs, hasMore: current.hasMore));
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

  Future<void> _fetchPage(
    Emitter<SongState> emit, {
    List<SongModel> previousSongs = const [],
  }) async {
    List<SongModel> page;
    try {
      page = await songRepository.getSongs(
        offset: _currentOffset,
        limit: Constants.pageSize,
      );
    } catch (e) {
      AppLogger.e('[SongBloc] getSongs failed: $e');
      emit(const SongError(SongErrorType.loadFailed));
      rethrow;
    }

    _currentOffset += page.length;

    int totalCount;
    try {
      totalCount = await songRepository.getSongCount();
    } catch (e) {
      AppLogger.e('[SongBloc] getSongCount failed: $e');
      emit(const SongError(SongErrorType.unknown));
      rethrow;
    }

    final hasMore = _currentOffset < totalCount;

    AppLogger.i(
      '[SongBloc] Loaded ${page.length} songs '
      '(offset: $_currentOffset / $totalCount)',
    );

    emit(SongLoaded(songs: [...previousSongs, ...page], hasMore: hasMore));
  }
}
