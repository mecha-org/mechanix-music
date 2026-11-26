import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/services/song_index.dart';

/// [SongIndex] kept in memory, for tests that must not load the native
/// Tantivy library. Mirrors `TantivySongIndex`: title order, prefix search
/// over title/artist/album, `/artist/album` grouping.
class InMemorySongIndex implements SongIndex {
  /// Stored songs by path.
  final Map<String, SongModel> songs = {};

  bool isOpen = false;

  /// Seeds the index (as if the songs had been stored earlier).
  void putAll(List<SongModel> list) {
    for (final song in list) {
      songs[song.path] = _copy(song);
    }
  }

  /// Copies keep only what the index stores, like the real one.
  static SongModel _copy(SongModel song) =>
      SongModel.fromJson(song.toJson())..isExternal = false;

  List<SongModel> get _sorted => songs.values.map(_copy).toList()
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  @override
  Future<void> open() async => isOpen = true;

  @override
  Future<int> count() async => songs.length;

  @override
  Future<List<SongModel>> getPage({
    required int offset,
    required int limit,
  }) async => _sorted.skip(offset).take(limit).toList();

  @override
  Future<List<SongModel>> getByPaths(List<String> paths) async => [
    for (final path in paths)
      if (songs[path] case final song?) _copy(song),
  ];

  @override
  Future<List<SongScanState>> getScanStates() async => [
    for (final song in songs.values)
      SongScanState(
        path: song.path,
        mtime: song.mtime,
        size: song.size,
        lastScannedAt: song.lastScannedAt,
      ),
  ];

  @override
  Future<void> upsert(List<SongModel> list) async => putAll(list);

  @override
  Future<void> delete(List<String> paths) async {
    for (final path in paths) {
      songs.remove(path);
    }
  }

  @override
  Future<List<SongModel>> search(String query, {int limit = 50}) async {
    final words = _words(query);
    if (words.isEmpty) return [];
    return _sorted
        .where((song) {
          final terms = _words(
            [song.title, song.artist, song.album ?? ''].join(' '),
          );
          return words.every((w) => terms.any((t) => t.startsWith(w)));
        })
        .take(limit)
        .toList();
  }

  static List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.isNotEmpty)
      .toList();

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    final counts = <(String, String), int>{};
    for (final song in songs.values) {
      final album = song.album;
      if (album == null || album.trim().isEmpty) continue;
      counts.update((song.artist, album), (n) => n + 1, ifAbsent: () => 1);
    }
    return [
      for (final MapEntry(key: (artist, album), value: count)
          in counts.entries)
        AlbumSummary(artist: artist, album: album, songCount: count),
    ]..sort((a, b) {
      final byArtist = a.artist.toLowerCase().compareTo(
        b.artist.toLowerCase(),
      );
      return byArtist != 0
          ? byArtist
          : a.album.toLowerCase().compareTo(b.album.toLowerCase());
    });
  }

  @override
  Future<List<SongModel>> getAlbumSongs(String artist, String album) async =>
      _sorted.where((s) => s.artist == artist && s.album == album).toList();

  @override
  Future<void> close() async => isOpen = false;
}
