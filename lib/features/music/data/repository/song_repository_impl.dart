import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

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

/// The song library: songs in the Tantivy index ([SongIndex]), favourites
/// in an `.m3u8` playlist ([FavouritesStore]).
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

  /// Favourite song paths, kept in sync via [FavouritesStore.changes].
  Set<String>? _favouritePaths;

  StreamSubscription<void>? _favouritesSub;

  Future<void>? _opening;

  /// One watcher per folder, by path (no recursive watch on Linux).
  final Map<String, StreamSubscription<FileSystemEvent>> _watchers = {};
  final Map<String, Timer> _debounceTimers = {};

  /// Removals held briefly to detect moves; see [_removeLater].
  final Map<String, ({String path, Timer timer})> _pendingRemovals = {};

  // Stream that bloc will listen to for live changes
  final StreamController<SongChange> _onSongChanged =
      StreamController<SongChange>.broadcast();

  @override
  Stream<SongChange> get onSongChanged => _onSongChanged.stream;

  final StreamController<List<String>> _onSongsRemoved =
      StreamController<List<String>>.broadcast();

  @override
  Stream<List<String>> get onSongsRemoved => _onSongsRemoved.stream;

  final StreamController<({String from, String to})> _onSongMoved =
      StreamController<({String from, String to})>.broadcast();

  @override
  Stream<({String from, String to})> get onSongMoved => _onSongMoved.stream;

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

  /// Whether [path] is under the music folder and not hidden. Other songs
  /// count as external.
  bool _isInMusicDir(String path) {
    final musicDir = _musicDirectoryProvider();
    if (!p.isWithin(musicDir, path)) return false;
    return !p.split(p.relative(path, from: musicDir)).any(_isHidden);
  }

  static bool _isHidden(String name) => name.startsWith('.');

  /// Whether [path] is an audio file the scan would pick up.
  bool _isScannedFile(String path) => isAudioFile(path) && _isInMusicDir(path);

  /// Folders and audio files under [root], skipping hidden entries,
  /// symlinked folders and unreadable folders. Each folder is yielded
  /// before it is listed, so it can be watched first.
  Stream<FileSystemEntity> _walk(String root) async* {
    final pending = [Directory(root)];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      yield dir;

      final List<FileSystemEntity> entities;
      try {
        entities = await dir.list(followLinks: false).toList();
      } on FileSystemException catch (e) {
        AppLogger.e('[SongRepository] Skipping unreadable folder: $e');
        continue;
      }
      for (final entity in entities) {
        if (_isHidden(p.basename(entity.path))) continue;
        if (entity is Directory) {
          pending.add(entity);
        } else if (isAudioFile(entity.path)) {
          if (entity is File) {
            yield entity;
          } else if (await FileSystemEntity.isFile(entity.path)) {
            yield File(entity.path); // a symlink to an audio file
          }
        }
      }
    }
  }

  /// Fills in the fields that are not stored in the index.
  SongModel _decorate(SongModel song) => song
    ..isFavourite = _favouritePaths?.contains(song.path) ?? false
    ..isExternal = !_isInMusicDir(song.path);

  List<SongModel> _decorateAll(List<SongModel> songs) =>
      songs.map(_decorate).toList();

  /// Stamps [song] with its file's mtime/size, and a new song with its
  /// date added (file mtime in the music folder, else now).
  Future<SongModel> _withFileStat(SongModel song) async {
    final stat = await File(song.path).stat();
    final found = stat.type != FileSystemEntityType.notFound;
    if (found) {
      song.mtime = stat.modified.millisecondsSinceEpoch;
      song.size = stat.size;
    }
    final now = DateTime.now().toUtc();
    song.lastScannedAt = now;
    if (song.addedAt == null) {
      final modified = DateTime.fromMillisecondsSinceEpoch(
        song.mtime,
        isUtc: true,
      );
      final fromFile =
          found && _isInMusicDir(song.path) && modified.isBefore(now);
      song.addedAt = fromFile ? modified : now;
    }
    return song;
  }

  /// Keeps the id and date added of [old].
  static void _keepIdentity(SongModel song, SongModel old) => song
    ..id = old.id
    ..addedAt = old.addedAt;

  /// Refreshes favourite flags and announces the songs that changed.
  Future<void> _onFavouritesChanged() async {
    final previous = _favouritePaths;
    if (previous == null) return; // not loaded yet: read when opening
    final current = (await _favourites.paths()).toSet();
    final changed = previous
        .difference(current)
        .union(current.difference(previous));
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
    await _stopWatchers();

    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    for (final pending in _pendingRemovals.values) {
      pending.timer.cancel();
    }
    _pendingRemovals.clear();

    await _onSongChanged.close();
    await _onSongsRemoved.close();
    await _onSongMoved.close();
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

      // 1. Compare files on disk with the index (mtime + size).
      final folders = <String>[];
      final diskPaths = <String>{};
      final newOrModified = <String>[];
      final dir = Directory(musicDir);
      if (await dir.exists()) {
        await for (final entity in _walk(musicDir)) {
          if (entity is Directory) {
            folders.add(entity.path);
            continue;
          }
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

      // 2. Drop songs whose file is gone.
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
        _startWatcher(folders);
        return false;
      }

      // 3. Drop the songs that are gone.
      await _index.delete(toRemove);
      if (toRemove.isNotEmpty && !_onSongsRemoved.isClosed) {
        _onSongsRemoved.add(toRemove);
      }

      // 4. Read tags off the UI isolate and save in batches.
      var updatedCount = 0;
      for (
        var start = 0;
        start < newOrModified.length;
        start += Constants.scanBatchSize
      ) {
        final batch = newOrModified.sublist(
          start,
          math.min(start + Constants.scanBatchSize, newOrModified.length),
        );
        final previous = {
          for (final song in await _index.getByPaths(batch)) song.path: song,
        };
        final updated = <SongModel>[];
        for (final song in await _scan(batch)) {
          if (previous[song.path] case final old?) _keepIdentity(song, old);
          updated.add(await _withFileStat(song));
        }
        await _index.upsert(updated);
        updatedCount += updated.length;
      }

      AppLogger.i(
        '[SongRepository] Sync completed for $musicDir: '
        '$updatedCount added/updated, ${toRemove.length} removed',
      );
      _startWatcher(folders);
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

  /// Reads the tags of [paths] on another isolate (static: captures
  /// nothing).
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
    String? after,
    required int limit,
    SongSort sort = SongSort.title,
  }) async {
    await ensureOpen();
    return _decorateAll(
      await _index.getPage(afterPath: after, limit: limit, sort: sort),
    );
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
    if (await _removeSongs([path])) {
      AppLogger.i('[SongRepository] Deleted song by path: $path');
    }
  }

  /// Removes and announces the songs at [paths]; true if any was removed.
  Future<bool> _removeSongs(List<String> paths) async {
    if (paths.isEmpty) return false;
    final songs = await _index.getByPaths(paths);
    if (songs.isEmpty) return false;

    final removed = [for (final song in songs) song.path];
    await _index.delete(removed);
    if (!_onSongsRemoved.isClosed) _onSongsRemoved.add(removed);
    if (!_onSongChanged.isClosed) {
      for (final song in songs) {
        _onSongChanged.add(
          SongChange(type: SongChangeType.delete, song: _decorate(song)),
        );
      }
    }
    return true;
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
  //
  // One watcher per folder (no recursive watch on Linux). A move between
  // folders arrives as delete + create, so a removal is held briefly and a
  // same-named arrival is treated as a move.

  /// Watches [folders] (music folder first).
  void _startWatcher(List<String> folders) {
    unawaited(_stopWatchers());

    if (folders.isEmpty) {
      AppLogger.e(
        '[FileWatcher] Music directory does not exist: '
        '${_musicDirectoryProvider()}. Skipping watcher.',
      );
      return;
    }
    folders.forEach(_watchFolder);
    AppLogger.i(
      '[FileWatcher] Watching ${folders.first} '
      '(${folders.length - 1} subfolders)',
    );
  }

  Future<void> _stopWatchers() async {
    final subscriptions = _watchers.values.toList();
    _watchers.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
  }

  void _watchFolder(String folder) {
    if (_watchers.containsKey(folder)) return;
    late final StreamSubscription<FileSystemEvent> subscription;
    void forget() {
      if (identical(_watchers[folder], subscription)) _watchers.remove(folder);
    }

    subscription = Directory(folder).watch().listen(
      _onFileSystemEvent,
      onError: (Object e) {
        AppLogger.e('[FileWatcher] Watching $folder failed: $e');
        forget();
        unawaited(subscription.cancel());
      },
      // The folder itself was deleted.
      onDone: forget,
    );
    _watchers[folder] = subscription;
  }

  /// Stops watching [root] and every folder under it.
  void _unwatchTree(String root) {
    final folders = _watchers.keys
        .where((w) => p.equals(w, root) || p.isWithin(root, w))
        .toList();
    for (final folder in folders) {
      unawaited(_watchers.remove(folder)!.cancel());
    }
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    final path = event.path;
    final destination = event is FileSystemMoveEvent
        ? event.destination
        : null;

    if (event.isDirectory) {
      switch (event.type) {
        case FileSystemEvent.create:
          if (_isInMusicDir(path)) unawaited(_onFolderAppeared(path));
        case FileSystemEvent.delete:
          _onFolderDisappeared(path);
        case FileSystemEvent.move:
          if (destination != null &&
              _isInMusicDir(path) &&
              _isInMusicDir(destination)) {
            unawaited(_onFolderMoved(path, destination));
          } else {
            // Moved out of and/or into the scanned part (e.g. hidden name).
            _onFolderDisappeared(path);
            if (destination != null && _isInMusicDir(destination)) {
              unawaited(_onFolderAppeared(destination));
            }
          }
      }
      return;
    }

    switch (event.type) {
      case FileSystemEvent.create:
        if (_isScannedFile(path)) _onFileAppeared(path);
      case FileSystemEvent.modify:
        if (_isScannedFile(path)) _debounce(path, () => _onFileSettled(path));
      case FileSystemEvent.delete:
        if (_isScannedFile(path)) _onFileDisappeared(path);
      case FileSystemEvent.move:
        final fromScanned = _isScannedFile(path);
        if (destination != null && _isScannedFile(destination)) {
          if (fromScanned) {
            _cancelDebounce(path);
            unawaited(_onMove(oldPath: path, newPath: destination));
          } else {
            // e.g. a download renamed from `song.mp3.part` to `song.mp3`.
            _debounce(destination, () => _onFileSettled(destination));
          }
        } else if (fromScanned) {
          _onFileDisappeared(path);
        }
    }
  }

  void _onFileAppeared(String path) {
    // Removed just before under the same name: moved here.
    final oldPath = _takePendingRemoval(path, isDirectory: false);
    if (oldPath != null && oldPath != path) {
      _cancelDebounce(oldPath);
      unawaited(_onMove(oldPath: oldPath, newPath: path));
      return;
    }
    _debounce(path, () => _onFileSettled(path));
  }

  /// Indexes [path], or moves a same-named song that just disappeared.
  void _onFileSettled(String path) {
    final oldPath = _takePendingRemoval(path, isDirectory: false);
    if (oldPath != null && oldPath != path) {
      unawaited(_onMove(oldPath: oldPath, newPath: path));
    } else {
      unawaited(_onUpsert(path));
    }
  }

  void _onFileDisappeared(String path) {
    _cancelDebounce(path);
    _removeLater(path, isDirectory: false);
  }

  /// Watches and indexes a new folder, or handles it as a move.
  Future<void> _onFolderAppeared(String folder) async {
    final oldFolder = _takePendingRemoval(folder, isDirectory: true);
    if (oldFolder != null) return _onFolderMoved(oldFolder, folder);

    await for (final entity in _walk(folder)) {
      if (entity is Directory) {
        _watchFolder(entity.path);
      } else {
        final path = entity.path;
        _debounce(path, () => _onUpsert(path));
      }
    }
  }

  void _onFolderDisappeared(String folder) {
    // Now: watchers follow the moved folder and report stale paths.
    _unwatchTree(folder);
    _removeLater(folder, isDirectory: true);
  }

  /// Moves the songs of folder [from] to [to], keeping ids and favourites.
  Future<void> _onFolderMoved(String from, String to) async {
    _unwatchTree(from);
    try {
      // New path → old path of every song that was under [from].
      final moved = <String, String>{
        for (final state in await _index.getScanStates())
          if (p.isWithin(from, state.path))
            p.join(to, p.relative(state.path, from: from)): state.path,
      };

      await for (final entity in _walk(to)) {
        if (entity is Directory) {
          _watchFolder(entity.path);
          continue;
        }
        final path = entity.path;
        final oldPath = moved.remove(path);
        if (oldPath != null && oldPath != path) {
          _cancelDebounce(oldPath);
          await _onMove(oldPath: oldPath, newPath: path);
        } else {
          _debounce(path, () => _onUpsert(path));
        }
      }

      final missing = moved.values.toList();
      missing.forEach(_cancelDebounce);
      await _removeSongs(missing);
      AppLogger.i('[FileWatcher] Folder moved: $from → $to');
    } catch (e) {
      AppLogger.e('[FileWatcher] Folder move failed $from → $to: $e');
    }
  }

  /// Removes the songs under [folder].
  Future<void> _removeSongsUnder(String folder) async {
    try {
      final paths = [
        for (final state in await _index.getScanStates())
          if (p.isWithin(folder, state.path)) state.path,
      ];
      paths.forEach(_cancelDebounce);
      if (await _removeSongs(paths)) {
        AppLogger.i('[FileWatcher] Folder removed: $folder');
      }
    } catch (e) {
      AppLogger.e('[FileWatcher] Removing songs under $folder failed: $e');
    }
  }

  static String _removalKey(String path, {required bool isDirectory}) =>
      '${isDirectory ? 'folder' : 'file'}:${p.basename(path)}';

  /// Removes [path] after a delay, unless [_takePendingRemoval] claims it.
  void _removeLater(String path, {required bool isDirectory}) {
    void remove(String path) => unawaited(
      isDirectory ? _removeSongsUnder(path) : deleteSongByPath(path),
    );

    final key = _removalKey(path, isDirectory: isDirectory);
    // Same name already pending: remove that one now.
    final previous = _pendingRemovals.remove(key);
    if (previous != null) {
      previous.timer.cancel();
      remove(previous.path);
    }
    _pendingRemovals[key] = (
      path: path,
      timer: Timer(Constants.debounceDuration, () {
        _pendingRemovals.remove(key);
        remove(path);
      }),
    );
  }

  /// Claims a pending removal with the name of [path], if any.
  String? _takePendingRemoval(String path, {required bool isDirectory}) {
    final pending = _pendingRemovals.remove(
      _removalKey(path, isDirectory: isDirectory),
    );
    if (pending == null) return null;
    pending.timer.cancel();
    return pending.path;
  }

  void _cancelDebounce(String path) {
    _debounceTimers.remove(path)?.cancel();
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
      if (existing.isNotEmpty) _keepIdentity(song, existing.first);

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
      if (found.isEmpty) {
        // Not in the library (yet): nothing moves, index the new file.
        await _onUpsert(newPath);
        return;
      }
      final existing = _decorate(found.first);

      final updated = await _fileScannerService.buildSongModel(newPath);
      if (updated == null) return;
      _keepIdentity(updated, existing);

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
      if (!_onSongMoved.isClosed) {
        _onSongMoved.add((from: oldPath, to: newPath));
      }
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
