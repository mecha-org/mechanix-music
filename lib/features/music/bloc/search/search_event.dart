import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the recent searches (when the screen opens).
final class SearchStarted extends SearchEvent {
  const SearchStarted();
}

/// The text in the search field changed. Searches after a short pause.
final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// A result or a recent song was opened: it moves to the top of the recent
/// searches.
final class SearchSongOpened extends SearchEvent {
  const SearchSongOpened(this.song);

  final SongModel song;

  @override
  List<Object?> get props => [song.path];
}

/// The X of a recent song was tapped.
final class SearchRecentRemoved extends SearchEvent {
  const SearchRecentRemoved(this.path);

  final String path;

  @override
  List<Object?> get props => [path];
}

/// The trash icon of the recent section was tapped.
final class SearchRecentsCleared extends SearchEvent {
  const SearchRecentsCleared();
}
