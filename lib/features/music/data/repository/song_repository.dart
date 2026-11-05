import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/album_summary.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

abstract class SongRepository {
  Future<bool> syncInitialSongLibrary();
  Future<List<SongModel>> getSongs({required int offset, required int limit});
  Future<int> getSongCount();
  Stream<SongChange> get onSongChanged;
  Future<void> addSongsByPaths(List<String> paths);
  Future<void> deleteSongByPath(String path);

  /// Marks the song at [path] as a favourite (or not) and announces the
  /// change on [onSongChanged].
  Future<void> setFavourite(String path, bool isFavourite);

  /// Library songs for [paths], in the same order. Paths that are not in the
  /// library are skipped.
  Future<List<SongModel>> getSongsByPaths(List<String> paths);

  /// The favourite songs, oldest favourite first.
  Future<List<SongModel>> getFavouriteSongs();

  /// Full-text search over title, artist and album, best match
  /// first. Words match by prefix, so partial input finds songs too.
  Future<List<SongModel>> searchSongs(
    String query, {
    int limit = Constants.searchResultLimit,
  });

  /// Every album (artist + album), ordered by artist then album.
  Future<List<AlbumSummary>> getAlbums();

  /// Songs of an album, ordered by title.
  Future<List<SongModel>> getAlbumSongs(String artist, String album);
}
