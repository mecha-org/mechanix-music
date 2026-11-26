import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.recents = const [],
    this.isSearching = false,
  });

  /// The trimmed search text.
  final String query;

  /// Library songs matching [query], best match first.
  final List<SongModel> results;

  /// Songs opened from search, newest first.
  final List<SongModel> recents;

  /// True while the results for [query] are being looked up.
  final bool isSearching;

  bool get hasQuery => query.isNotEmpty;

  SearchState copyWith({
    String? query,
    List<SongModel>? results,
    List<SongModel>? recents,
    bool? isSearching,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    recents: recents ?? this.recents,
    isSearching: isSearching ?? this.isSearching,
  );

  // SongModel has no value equality, so compare by path.
  @override
  List<Object?> get props => [
    query,
    [for (final song in results) song.path],
    [for (final song in recents) song.path],
    isSearching,
  ];
}
