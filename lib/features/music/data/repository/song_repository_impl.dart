import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:mechanix_music/core/exceptions/app_exceptions.dart';
import 'package:mechanix_music/core/services/file_scanner_service.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/core/utils/helper.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:mechanix_music/features/music/data/services/song_index.dart';
import 'package:mechanix_music/features/music/data/services/tantivy_song_index.dart';
import 'package:path/path.dart' as p;

/// The song library.
///
/// Songs live in the Tantivy music index ([SongIndex]): paging, counting,
/// lookups and search all go to the index. Favourites are an `.m3u8`
/// playlist ([FavouritesStore]).
class SongRepositoryImpl extends SongRepository {
  SongRepositoryImpl({
    FileScannerService? fileScannerService,
    SongIndex? songIndex,
    FavouritesStore? favouritesStore,
    String Function()? musicDirectoryProvider,
  }) : _fileScannerService = fileScannerService ?? FileScannerService(),
       // An injected scanner (tests) cannot be sent to another isolate.
       _scanInIsolate = fileScannerService == null,
       _index = songIndex ?? TantivySongIndex(),
       _favourites = favouritesStore ?? FavouritesStore(),
       _musicDirectoryProvider = musicDirectoryProvider ?? getMusicDirectory {
    // The favourites are also edited as the Favourites playlist.
    _favouritesSub = _favourites.changes.listen((_) => _onFavouritesChanged());
  }

  final FileScannerService _fileScannerService;
  final bool _scanInIsolate;
  final SongIndex _index;
  final FavouritesStore _favourites;
  final String Function() _musicDirectoryProvider;

  /// Paths of the favourite songs, loaded once from the `.m3u8` file and
  /// kept up to date through [FavouritesStore.changes].
  Set<String>? _favouritePaths;

  StreamSubscription<void>? _favouritesSub;

  Future<void>? _opening;

  StreamSubscription<FileSystemEvent>? _watcherSubscription;
  final Map<String, Timer> _debounceTimers = {};

  // Stream that bloc will listen to for live changes
  final StreamController<SongChange> _onSongChanged =
      StreamController<SongChange>.broadcast();

  @override
  Stream<SongChange> get onSongChanged => _onSongChanged.stream;

  /// Opens the index and loads the favourites (once).
  Future<void> ensureOpen() async {
    final opening = _opening ??= _open();
    try {
      await opening;
    } catch (e) {
      // Allow a retry on the next call.
      if (identical(_opening, opening)) _opening = null;
      AppLogger.e('[SongRepository] Opening the library failed: $e');
      rethrow;
    }
  }

  Future<void> _open() async {
    await _index.open();
    _favouritePaths = (await _favourites.paths()).toSet();
  }

  /// Whether [path] is directly inside the music folder (the folder that
  /// is scanned). Other songs were imported and count as external.
  bool _isInMusicDir(String path) =>
      p.equals(p.dirname(path), _musicDirectoryProvider());

  /// Fills in the fields that are not stored in the index.
  SongModel _decorate(SongModel song) => song
    ..isFavourite = _favouritePaths?.contains(song.path) ?? false
    ..isExternal = !_isInMusicDir(song.path);

  List<SongModel> _decorateAll(List<SongModel> songs) =>
      songs.map(_decorate).toList();

  /// Stamps [song] with the current mtime/size of its file.
  Future<SongModel> _withFileStat(SongModel song) async {
    final stat = await File(song.path).stat();
    if (stat.type != FileSystemEntityType.notFound) {
      song.mtime = stat.modified.millisecondsSinceEpoch;
      song.size = stat.size;
    }
    song.lastScannedAt = DateTime.now().toUtc();
    return song;
  }

  /// Refreshes the favourite flags after the favourites changed (e.g. a
  /// song was added to or removed from the Favourites playlist) and
  /// announces the songs whose flag changed.
  Future<void> _onFavouritesChanged() async {
    final previous = _favouritePaths;
    if (previous == null) return; // not loaded yet: read when opening
    final current = (await _favourites.paths()).toSet();
    final changed = previous.difference(current).union(
      current.difference(previous),
    );
    _favouritePaths = current;
    if (changed.isEmpty || _onSongChanged.isClosed) return;

    try {
      for (final song in await _index.getByPaths(changed.toList())) {
        _onSongChanged.add(
          SongChange(type: SongChangeType.upsert, song: _decorate(song)),
        );
      }
    } catch (e) {
      AppLogger.e('[SongRepository] Refreshing favourites failed: $e');
    }
  }

  /// Stops watching the music folder and closes the index.
  Future<void> close() async {
    await _favouritesSub?.cancel();
    _favouritesSub = null;
    await _watcherSubscription?.cancel();
    _watcherSubscription = null;

    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();

    await _onSongChanged.close();
    await _index.close();
    _opening = null;
    _favouritePaths = null;
  }

  @override
  Future<bool> syncInitialSongLibrary() async {
    try {
      await ensureOpen();
      final musicDir = _musicDirectoryProvider();
      final stored = {
        for (final state in await _index.getScanStates()) state.path: state,
      };

      // 1. Compare the music folder with the index (mtime + size).
      final diskPaths = <String>{};
      final newOrModified = <String>[];
      final dir = Directory(musicDir);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is! File || !isAudioFile(entity.path)) continue;
          final path = entity.path;
          diskPaths.add(path);

          final state = stored[path];
          if (state == null) {
            newOrModified.add(path);
            continue;
          }
          final stat = await entity.stat();
          if (stat.modified.millisecondsSinceEpoch != state.mtime ||
              stat.size != state.size) {
            newOrModified.add(path);
          }
        }
      }

      // 2. Songs to drop: songs of the music folder that left it, and
      //    imported (external) songs whose file is gone.
      final toRemove = <String>[];
      for (final path in stored.keys) {
        if (_isInMusicDir(path)) {
          if (!diskPaths.contains(path)) toRemove.add(path);
          continue;
        }
        try {
          if (!await File(path).exists()) toRemove.add(path);
        } catch (e) {
          AppLogger.e('Error checking existence of custom song $path: $e');
          toRemove.add(path);
        }
      }

      if (toRemove.isEmpty && newOrModified.isEmpty) {
        AppLogger.i('[SongRepository] Library is up to date for $musicDir');
        _startWatcher();
        return false;
      }

      // 3. Read the tags of new/modified files (slow, so off the UI isolate).
      final previous = {
        for (final song in await _index.getByPaths(newOrModified))
          song.path: song,
      };
      final updated = <SongModel>[];
      for (final song in await _scan(newOrModified)) {
        // Keep the id stable across rescans.
        if (previous[song.path] case final old?) song.id = old.id;
        updated.add(await _withFileStat(song));
      }

      // 4. Save.
      await _index.delete(toRemove);
      await _index.upsert(updated);

      AppLogger.i(
        '[SongRepository] Sync completed for $musicDir: '
        '${updated.length} added/updated, ${toRemove.length} removed',
      );
      _startWatcher();
      return true;
    } on AppAlreadyRunningException catch (_) {
      rethrow;
    } catch (e) {
      AppLogger.e('[SongRepository] syncInitialSongLibrary failed: $e');
      return false;
    }
  }

  /// Builds song models for [paths], skipping files without a model.
  Future<List<SongModel>> _scan(List<String> paths) async {
    if (paths.isEmpty) return [];
    if (!_scanInIsolate) {
      return [
        for (final path in paths)
          if (await _fileScannerService.buildSongModel(path) case final song?)
            song,
      ];
    }

    final scanned = await _scanInBackground(paths);
    return scanned.map(SongModel.fromJson).toList();
  }

  /// Reads the tags of [paths] on another isolate. Static so the isolate
  /// closure cannot capture the repository. Plain maps cross the isolate
  /// boundary.
  static Future<List<Map<String, Object?>>> _scanInBackground(
    List<String> paths,
  ) => Isolate.run(() async {
    final scanner = FileScannerService();
    return [
      for (final path in paths)
        if (await scanner.buildSongModel(path) case final song?) song.toJson(),
    ];
  });

  @override
  Future<List<SongModel>> getSongs({
    required int offset,
    required int limit,
  }) async {
    await ensureOpen();
    return _decorateAll(await _index.getPage(offset: offset, limit: limit));
  }

  @override
  Future<int> getSongCount() async {
    await ensureOpen();
    return _index.count();
  }

  @override
  Future<void> addSongsByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    await ensureOpen();

    final unique = paths.toSet().toList();
    final existing = {
      for (final song in await _index.getByPaths(unique)) song.path,
    };
    final newPaths = unique.where((p) => !existing.contains(p)).toList();

    AppLogger.i(
      '[SongRepository] ${existing.length} already in library, '
      '${newPaths.length} to import',
    );

    final added = <SongModel>[];
    for (final path in newPaths) {
      try {
        final song = await _fileScannerService.buildSongModel(path);
        if (song == null) {
          AppLogger.i('[SongRepository] Could not build model for: $path');
          continue;
        }
        added.add(_decorate(await _withFileStat(song)));
      } catch (e) {
        AppLogger.e('[SongRepository] addSongsByPaths failed for $path: $e');
      }
    }

    await _index.upsert(added);
    for (final song in added) {
      AppLogger.i('[SongRepository] Added to library: ${song.title}');
      _onSongChanged.add(SongChange(type: SongChangeType.upsert, song: song));
    }
  }

  @override
  Future<void> deleteSongByPath(String path) async {
    await ensureOpen();
    final existing = await _index.getByPaths([path]);
    if (existing.isEmpty) return;

    await _index.delete([path]);
    AppLogger.i('[SongRepository] Deleted song by path: $path');
    _onSongChanged.add(
      SongChange(type: SongChangeType.delete, song: _decorate(existing.first)),
    );
  }

  @override
  Future<void> setFavourite(String path, bool isFavourite) async {
    await ensureOpen();
    final found = await _index.getByPaths([path]);
    if (found.isEmpty) return;
    final song = _decorate(found.first);
    if (song.isFavourite == isFavourite) return;

    await _favourites.set(song, isFavourite);
    if (isFavourite) {
      _favouritePaths?.add(path);
    } else {
      _favouritePaths?.remove(path);
    }
    song.isFavourite = isFavourite;
    AppLogger.i('[SongRepository] Favourite=$isFavourite for: $path');
    _onSongChanged.add(SongChange(type: SongChangeType.upsert, song: song));
  }

  @override
  Future<List<SongModel>> getSongsByPaths(List<String> paths) async {
    if (paths.isEmpty) return [];
    await ensureOpen();
    return _decorateAll(await _index.getByPaths(paths));
  }

  @override
  Future<List<SongModel>> getFavouriteSongs() async {
    await ensureOpen();
    return getSongsByPaths(await _favourites.paths());
  }

  @override
  Future<List<SongModel>> searchSongs(
    String query, {
    int limit = Constants.searchResultLimit,
  }) async {
    if (query.trim().isEmpty) return [];
    await ensureOpen();
    try {
      return _decorateAll(await _index.search(query, limit: limit));
    } catch (e) {
      AppLogger.e('[SongRepository] searchSongs failed ($query): $e');
      return [];
    }
  }

  @override
  Future<List<AlbumSummary>> getAlbums() async {
    await ensureOpen();
    return _index.getAlbums();
  }

  @override
  Future<List<SongModel>> getAlbumSongs(String artist, String album) async {
    await ensureOpen();
    return _decorateAll(await _index.getAlbumSongs(artist, album));
  }

  // ── Watcher ──────────────────────────────────────────────────────────────

  void _startWatcher() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;

    final musicDir = _musicDirectoryProvider();
    final dir = Directory(musicDir);
    if (!dir.existsSync()) {
      AppLogger.e(
        '[FileWatcher] Music directory does not exist: $musicDir. Skipping watcher.',
      );
      return;
    }

    _watcherSubscription = dir.watch(recursive: false).listen((event) {
      if (!isAudioFile(event.path)) return;

      switch (event.type) {
        case FileSystemEvent.create:
        case FileSystemEvent.modify:
          _debounce(event.path, () => _onUpsert(event.path));

        case FileSystemEvent.delete:
          // Cancel any pending debounce for this path and act immediately
          _debounceTimers[event.path]?.cancel();
          _debounceTimers.remove(event.path);
          deleteSongByPath(event.path);

        case FileSystemEvent.move:
          final moveEvent = event as FileSystemMoveEvent;
          final destination = moveEvent.destination;
          if (destination == null) return;

          // Cancel pending debounce for old path and act immediately
          _debounceTimers[moveEvent.path]?.cancel();
          _debounceTimers.remove(moveEvent.path);
          _onMove(oldPath: moveEvent.path, newPath: destination);
      }
    });

    AppLogger.i('[FileWatcher] Watching $musicDir');
  }

  void _debounce(String path, void Function() action) {
    _debounceTimers[path]?.cancel();
    _debounceTimers[path] = Timer(Constants.debounceDuration, () {
      _debounceTimers.remove(path);
      action();
    });
  }

  Future<void> _onUpsert(String path) async {
    try {
      final song = await _fileScannerService.buildSongModel(path);
      if (song == null) return;

      final existing = await _index.getByPaths([path]);
      if (existing.isNotEmpty) song.id = existing.first.id;

      await _index.upsert([await _withFileStat(song)]);
      AppLogger.i('[FileWatcher] Upserted: $path');
      _onSongChanged.add(
        SongChange(type: SongChangeType.upsert, song: _decorate(song)),
      );
    } catch (e) {
      AppLogger.e('[FileWatcher] Upsert failed for $path: $e');
    }
  }

  Future<void> _onMove({
    required String oldPath,
    required String newPath,
  }) async {
    try {
      final found = await _index.getByPaths([oldPath]);
      if (found.isEmpty) return;
      final existing = _decorate(found.first);

      final updated = await _fileScannerService.buildSongModel(newPath);
      if (updated == null) return;
      updated.id = existing.id;

      await _index.delete([oldPath]);
      await _index.upsert([await _withFileStat(updated)]);

      // Favourites are stored by path, so the favourite moves too.
      if (existing.isFavourite) {
        await _favourites.set(existing, false);
        await _favourites.set(updated, true);
        _favouritePaths
          ?..remove(oldPath)
          ..add(newPath);
      }

      AppLogger.i('[FileWatcher] Moved: $oldPath → $newPath');
      _onSongChanged.add(
        SongChange(type: SongChangeType.delete, song: existing),
      );
      _onSongChanged.add(
        SongChange(type: SongChangeType.upsert, song: _decorate(updated)),
      );
    } catch (e) {
      AppLogger.e('[FileWatcher] Move failed $oldPath → $newPath: $e');
    }
  }

  bool isAudioFile(String path) {
    final lower = path.toLowerCase();
    return Constants.audioExt.any((ext) => lower.endsWith(ext));
  }
}
