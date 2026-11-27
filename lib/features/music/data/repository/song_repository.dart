import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/data/models/album_summary.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

abstract class SongRepository {
  Future<bool> syncInitialSongLibrary();
  /// Up to [limit] songs in [sort] order after the song at [after].
  Future<List<SongModel>> getSongs({
    String? after,
    required int limit,
    SongSort sort = SongSort.title,
  });

  Future<int> getSongCount();
  Stream<SongChange> get onSongChanged;

  /// Paths of songs that left the library because their file is gone
  /// (deleted from the music folder, or found missing on start or play).
  Stream<List<String>> get onSongsRemoved;

  /// A song's file was renamed or moved within the music folder.
  Stream<({String from, String to})> get onSongMoved;
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
