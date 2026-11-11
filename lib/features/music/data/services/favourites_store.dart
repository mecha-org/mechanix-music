import 'dart:async';
import 'dart:io';

import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:path/path.dart' as p;

/// The user's favourite songs, kept as an `.m3u8` playlist (oldest
/// favourite first) so other players can use it too.
///
/// One instance is shared by the song repository (the favourite flag of
/// songs) and the playlist repository (the fixed "Favourites" playlist);
/// [changes] tells each of them when the other one edited the list.
class FavouritesStore {
  FavouritesStore({
    String Function()? filePathProvider,
    String? Function()? legacyFilePathProvider,
    M3u8Service m3u8Service = const M3u8Service(),
  }) : _filePathProvider = filePathProvider ?? _defaultFilePath,
       // Only the default location has an older one to migrate from.
       _legacyFilePathProvider =
           legacyFilePathProvider ??
           (filePathProvider == null ? _defaultLegacyFilePath : () => null),
       _m3u8 = m3u8Service;

  final String Function() _filePathProvider;
  final String? Function() _legacyFilePathProvider;
  final M3u8Service _m3u8;

  List<M3u8Entry>? _entries;

  /// Serialises writes so concurrent edits cannot interleave.
  Future<void> _lastWrite = Future.value();

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every change of the favourites.
  Stream<void> get changes => _changes.stream;

  static String _defaultFilePath() {
    final home = Platform.environment['HOME'] ?? '/home';
    return p.join(home, Constants.favouritesFilePath);
  }

  static String _defaultLegacyFilePath() {
    final home = Platform.environment['HOME'] ?? '/home';
    return p.join(home, Constants.legacyFavouritesFilePath);
  }

  File get _file => File(_filePathProvider());

  /// Path of the favourites file (inside the playlists folder), so the
  /// playlist repository can leave it out of the user playlists.
  String get filePath => _file.path;

  /// Moves the favourites from their old location (outside the playlists
  /// folder) when only the old file exists.
  Future<void> _migrate() async {
    final legacyPath = _legacyFilePathProvider();
    if (legacyPath == null) return;
    try {
      final legacy = File(legacyPath);
      if (!await legacy.exists() || await _file.exists()) return;
      await _file.parent.create(recursive: true);
      await legacy.rename(_file.path);
    } catch (_) {
      // Keep going with whatever is at the new location.
    }
  }

  Future<List<M3u8Entry>> _load() async {
    if (_entries case final entries?) return entries;
    await _migrate();
    return _entries ??= (await _m3u8.read(_file))?.entries.toList() ?? [];
  }

  /// Paths of the favourite songs, oldest favourite first.
  Future<List<String>> paths() async => [
    for (final entry in await _load()) entry.path,
  ];

  /// The favourites with their `#EXTINF` info, oldest favourite first.
  Future<List<M3u8Entry>> entries() async => [...await _load()];

  /// When the favourites file was created (its modification time if it
  /// has no creation tag), or null if there is no file yet.
  Future<DateTime?> createdAt() async {
    await _load();
    try {
      final playlist = await _m3u8.read(_file);
      if (playlist == null) return null;
      return playlist.createdAt ?? (await _file.stat()).modified.toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _lastWrite.then((_) => action());
    _lastWrite = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _write(List<M3u8Entry> entries) async {
    await _m3u8.write(
      _file,
      M3u8Playlist(name: Constants.favouritesPlaylistName, entries: entries),
    );
    _entries = entries;
    _changes.add(null);
  }

  /// Replaces the favourites with [entries] (in play order), e.g. after
  /// songs were added, removed or reordered in the Favourites playlist.
  Future<void> setEntries(List<M3u8Entry> entries) =>
      _serialized(() => _write([...entries]));

  /// Adds [song] to the end of the favourites, or removes it.
  Future<void> set(SongModel song, bool isFavourite) =>
      _serialized(() => _set(song, isFavourite));

  Future<void> _set(SongModel song, bool isFavourite) async {
    final entries = await _load();
    final index = entries.indexWhere((e) => e.path == song.path);
    if (isFavourite == (index != -1)) return;

    final updated = [...entries];
    if (isFavourite) {
      updated.add(
        M3u8Entry(
          path: song.path,
          durationSeconds: song.durationInSeconds,
          title: '${song.artist} - ${song.title}',
        ),
      );
    } else {
      updated.removeAt(index);
    }

    await _write(updated);
  }

  /// Releases the change stream.
  Future<void> dispose() => _changes.close();
}
