import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/bloc/search/search_event.dart';
import 'package:mechanix_music/features/music/bloc/search/search_state.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';

export 'search_event.dart';
export 'search_state.dart';

/// Library search (Tantivy, via [SongRepository.searchSongs]) and the
/// recent searches shown under the results.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc({
    required SongRepository songRepository,
    required RecentSearchRepository recentSearchRepository,
    Duration debounce = Constants.searchDebounce,
  }) : _songs = songRepository,
       _recentSearches = recentSearchRepository,
       _debounce = debounce,
       super(const SearchState()) {
    on<SearchStarted>(_onStarted);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchSongOpened>(_onSongOpened);
    on<SearchRecentRemoved>(_onRecentRemoved);
    on<SearchRecentsCleared>(_onRecentsCleared);
  }

  final SongRepository _songs;
  final RecentSearchRepository _recentSearches;
  final Duration _debounce;

  /// Increases with every query, so a slow search for old text cannot
  /// overwrite newer results.
  int _searchId = 0;

  Future<void> _onStarted(SearchStarted event, Emitter<SearchState> emit) =>
      _loadRecents(emit);

  Future<void> _loadRecents(Emitter<SearchState> emit) async {
    try {
      final paths = await _recentSearches.getRecentPaths();
      // Songs that left the library are skipped.
      emit(state.copyWith(recents: await _songs.getSongsByPaths(paths)));
    } catch (e) {
      AppLogger.e('[SearchBloc] Loading recent searches failed: $e');
    }
  }

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final query = event.query.trim();
    final id = ++_searchId;

    if (query.isEmpty) {
      emit(state.copyWith(query: '', results: const [], isSearching: false));
      return;
    }
    emit(state.copyWith(query: query, isSearching: true));

    await Future<void>.delayed(_debounce);
    if (id != _searchId) return; // typed again meanwhile

    try {
      final results = await _songs.searchSongs(query);
      if (id != _searchId) return;
      emit(state.copyWith(results: results, isSearching: false));
    } catch (e) {
      AppLogger.e('[SearchBloc] Search failed ($query): $e');
      if (id == _searchId) {
        emit(state.copyWith(results: const [], isSearching: false));
      }
    }
  }

  Future<void> _onSongOpened(
    SearchSongOpened event,
    Emitter<SearchState> emit,
  ) async {
    final song = event.song;
    emit(
      state.copyWith(
        recents: [
          song,
          ...state.recents.where((s) => s.path != song.path),
        ].take(Constants.recentSearchesLimit).toList(),
      ),
    );
    try {
      await _recentSearches.add(song.path);
    } catch (e) {
      AppLogger.e('[SearchBloc] Saving recent search failed: $e');
    }
  }

  Future<void> _onRecentRemoved(
    SearchRecentRemoved event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        recents: state.recents.where((s) => s.path != event.path).toList(),
      ),
    );
    try {
      await _recentSearches.remove(event.path);
    } catch (e) {
      AppLogger.e('[SearchBloc] Removing recent search failed: $e');
    }
  }

  Future<void> _onRecentsCleared(
    SearchRecentsCleared event,
    Emitter<SearchState> emit,
  ) async {
    emit(state.copyWith(recents: const []));
    try {
      await _recentSearches.clear();
    } catch (e) {
      AppLogger.e('[SearchBloc] Clearing recent searches failed: $e');
    }
  }
}
