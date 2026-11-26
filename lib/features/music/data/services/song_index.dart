import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/album_summary.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

export 'package:mechanix_music/features/music/data/models/album_summary.dart';

/// What a library scan needs to know about an indexed file.
class SongScanState extends Equatable {
  const SongScanState({
    required this.path,
    required this.mtime,
    required this.size,
    required this.lastScannedAt,
  });

  final String path;

  /// File modification time when scanned (ms since epoch).
  final int mtime;

  /// File size in bytes when scanned.
  final int size;

  final DateTime lastScannedAt;

  @override
  List<Object?> get props => [path, mtime, size, lastScannedAt];
}

/// Persistent, searchable store of the song library, keyed by
/// [SongModel.path].
///
/// The production implementation is `TantivySongIndex`; tests use an
/// in-memory one. Returned songs have [SongModel.isFavourite] and
/// [SongModel.isExternal] unset: the repository fills them in.
abstract class SongIndex {
  /// Opens the index. Safe to call more than once.
  Future<void> open();

  /// Number of songs.
  Future<int> count();

  /// A page of songs ordered by title (case-insensitive).
  Future<List<SongModel>> getPage({required int offset, required int limit});

  /// Songs at [paths], in the same order. Unknown paths are skipped.
  Future<List<SongModel>> getByPaths(List<String> paths);

  /// Path, mtime, size and scan time of every song (for library syncs).
  Future<List<SongScanState>> getScanStates();

  /// Inserts [songs], replacing songs with the same path.
  Future<void> upsert(List<SongModel> songs);

  /// Removes the songs at [paths].
  Future<void> delete(List<String> paths);

  /// Songs matching [query] (title, artist or album, words matched by
  /// prefix), best match first.
  Future<List<SongModel>> search(String query, {int limit});

  /// Every album, ordered by artist then album.
  Future<List<AlbumSummary>> getAlbums();

  /// Songs of an album, ordered by title.
  Future<List<SongModel>> getAlbumSongs(String artist, String album);

  /// Releases the index.
  Future<void> close();
}
