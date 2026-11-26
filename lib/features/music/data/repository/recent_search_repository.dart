/// Songs the user opened from search, newest first.
abstract class RecentSearchRepository {
  /// Paths of the recent songs, newest first.
  Future<List<String>> getRecentPaths();

  /// Moves [path] to the top (adds it if new), keeping at most the
  /// configured number of songs.
  Future<void> add(String path);

  /// Removes [path] from the recent songs.
  Future<void> remove(String path);

  /// Removes every recent song.
  Future<void> clear();
}
