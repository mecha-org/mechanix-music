import 'dart:io';
import 'dart:math' as math;

// Prefixed: some plugin functions (e.g. getScanStates) have the same names
// as SongIndex methods and would otherwise call this class recursively.
import 'package:flutter_tantivy/flutter_tantivy.dart' as tantivy;
import 'package:mechanix_music/core/exceptions/app_exceptions.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/services/song_index.dart';
import 'package:path/path.dart' as p;

/// [SongIndex] backed by the `flutter_tantivy` index (`initTantivy`,
/// `listDocuments`, …).
class TantivySongIndex implements SongIndex {
  TantivySongIndex({String Function()? indexDirectoryProvider})
    : _indexDirectoryProvider =
          indexDirectoryProvider ?? _defaultIndexDirectory;

  final String Function() _indexDirectoryProvider;

  /// The Rust bridge may only be initialised once per isolate.
  static Future<void>? _rustLibInit;

  bool _opened = false;

  static String _defaultIndexDirectory() {
    final home = Platform.environment['HOME'] ?? '/home';
    return p.join(home, Constants.tantivyIndexPath);
  }

  @override
  Future<void> open() async {
    if (_opened) return;
    _rustLibInit ??= tantivy.RustLib.init();
    try {
      await _rustLibInit;
    } catch (e) {
      _rustLibInit = null;
      rethrow;
    }

    final dir = Directory(_indexDirectoryProvider());
    await dir.create(recursive: true);
    try {
      tantivy.initTantivy(dirPath: dir.path, tokenizerType: 'default');
    } catch (e) {
      // Tantivy allows a single index writer per directory, so a second
      // instance of the app fails to take the lock.
      if (e.toString().contains('LockBusy')) {
        throw AppAlreadyRunningException();
      }
      rethrow;
    }
    _opened = true;
    AppLogger.i('[TantivySongIndex] Opened at ${dir.path}');
  }

  @override
  Future<int> count() async {
    await open();
    return tantivy.getNumDocs().toInt();
  }

  @override
  Future<List<SongModel>> getPage({
    required int offset,
    required int limit,
  }) async {
    await open();
    final tracks = await tantivy.listDocuments(
      offset: BigInt.from(offset),
      limit: BigInt.from(limit),
      sort: tantivy.SortOrder.title,
    );
    return _toSongs(tracks);
  }

  @override
  Future<List<SongModel>> getByPaths(List<String> paths) async {
    if (paths.isEmpty) return [];
    await open();
    return _toSongs(await tantivy.getDocumentsByPaths(paths: paths));
  }

  @override
  Future<List<SongScanState>> getScanStates() async {
    await open();
    return [
      for (final state in await tantivy.getScanStates())
        SongScanState(
          path: state.path,
          mtime: state.mtime.toInt(),
          size: state.size.toInt(),
          lastScannedAt: DateTime.fromMillisecondsSinceEpoch(
            state.lastScannedAt.toInt(),
            isUtc: true,
          ),
        ),
    ];
  }

  @override
  Future<void> upsert(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    await open();
    await tantivy.addDocumentsBatch(docs: songs.map(_toTrack).toList());
  }

  @override
  Future<void> delete(List<String> paths) async {
    if (paths.isEmpty) return;
    await open();
    await tantivy.deleteDocumentsBatch(paths: paths);
  }

  @override
  Future<List<SongModel>> search(
    String query, {
    int limit = Constants.searchResultLimit,
  }) async {
    if (query.trim().isEmpty) return [];
    await open();
    final tracks = (await tantivy.searchDocumentsPrefix(
      query: query,
      topK: BigInt.from(limit),
    )).results.map((result) => result.doc).toList();
    AppLogger.d('[TantivySongIndex] Search "$query" -> ${tracks.length}');
    return _toSongs(tracks);
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    await open();
    return [
      for (final album in await tantivy.listAlbums())
        AlbumSummary(
          artist: album.artist,
          album: album.album,
          songCount: album.trackCount.toInt(),
        ),
    ];
  }

  @override
  Future<List<SongModel>> getAlbumSongs(String artist, String album) async {
    await open();
    final tracks = await tantivy.listAlbumDocuments(
      artist: artist,
      album: album,
    );
    return _toSongs(tracks);
  }

  @override
  Future<void> close() async {
    if (!_opened) return;
    tantivy.closeTantivy();
    _opened = false;
  }

  /// Unsigned values for the index (a missing file has size -1).
  static BigInt _u64(int value) => BigInt.from(math.max(0, value));

  static tantivy.Document _toTrack(SongModel song) => tantivy.Document(
    path: song.path,
    uid: song.id,
    title: song.title,
    artist: song.artist,
    album: song.album,
    durationMs: switch (song.durationInSeconds) {
      final seconds? => BigInt.from(seconds * 1000),
      null => null,
    },
    mtime: _u64(song.mtime),
    size: _u64(song.size),
    artworkBase64: song.artworkBase64,
    lastScannedAt: _u64(song.lastScannedAt.millisecondsSinceEpoch),
  );

  static List<SongModel> _toSongs(List<tantivy.Document> tracks) =>
      tracks.map(_toSong).toList();

  static SongModel _toSong(tantivy.Document track) => SongModel(
    id: track.uid,
    path: track.path,
    title: track.title,
    artist: track.artist,
    album: track.album,
    duration: switch (track.durationMs) {
      final ms? => SongModel.formatDuration(ms.toInt() ~/ 1000),
      null => null,
    },
    artworkBase64: track.artworkBase64,
    lastScannedAt: DateTime.fromMillisecondsSinceEpoch(
      track.lastScannedAt.toInt(),
      isUtc: true,
    ),
    mtime: track.mtime.toInt(),
    size: track.size.toInt(),
  );
}
