import 'dart:io';

import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:path/path.dart' as p;

/// Playlists stored as one `.m3u8` file each in the playlists folder
/// ([Constants.playlistsDirPath]), plus the fixed Favourites playlist,
/// which is `favourites.m3u8` in the same folder ([FavouritesStore]) and is
/// not listed as a user playlist.
///
/// The file name (without `.m3u8`) is the playlist id and never changes; the
/// display name is the `#PLAYLIST` tag, so renaming only rewrites the tag.
/// Favourites always comes first and cannot be renamed or deleted.
class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl({
    String Function()? playlistsDirectoryProvider,
    SongRepository? songRepository,
    FavouritesStore? favouritesStore,
    M3u8Service m3u8Service = const M3u8Service(),
  }) : _directoryProvider =
           playlistsDirectoryProvider ?? _defaultPlaylistsDirectory,
       _songRepository = songRepository,
       _favourites = favouritesStore ?? FavouritesStore(),
       _m3u8 = m3u8Service;

  final String Function() _directoryProvider;

  /// Used to write song titles and durations into `#EXTINF` lines.
  final SongRepository? _songRepository;
  final FavouritesStore _favourites;
  final M3u8Service _m3u8;

  /// Serialises file writes so concurrent edits cannot interleave.
  Future<void> _lastWrite = Future.value();

  static const _favouritesId = PlaylistModel.favouritesId;

  static String _defaultPlaylistsDirectory() {
    final home = Platform.environment['HOME'] ?? '/home';
    return p.join(home, Constants.playlistsDirPath);
  }

  @override
  Stream<void> get onChanged => _favourites.changes;

  Directory get _directory => Directory(_directoryProvider());

  File _fileFor(String id) =>
      File(p.join(_directory.path, '$id${M3u8Service.extension}'));

  /// Whether [file] is the favourites file (shown as Favourites only).
  bool _isFavouritesFile(File file) =>
      p.equals(p.absolute(file.path), p.absolute(_favourites.filePath));

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _lastWrite.then((_) => action());
    _lastWrite = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<PlaylistModel> _readFavourites() async => PlaylistModel(
    id: _favouritesId,
    name: Constants.favouritesPlaylistName,
    createdAt:
        await _favourites.createdAt() ?? DateTime.fromMillisecondsSinceEpoch(0),
    songPaths: await _favourites.paths(),
    isFixed: true,
  );

  Future<PlaylistModel?> _read(String id) async {
    if (id == _favouritesId) return _readFavourites();
    return _readFile(_fileFor(id));
  }

  Future<PlaylistModel?> _readFile(File file) async {
    try {
      final playlist = await _m3u8.read(file);
      if (playlist == null) return null;
      final id = p.basenameWithoutExtension(file.path);
      return PlaylistModel(
        id: id,
        name: playlist.name ?? id,
        createdAt: playlist.createdAt ?? (await file.stat()).modified.toUtc(),
        songPaths: playlist.paths,
      );
    } catch (e) {
      AppLogger.e('[PlaylistRepository] Could not read ${file.path}: $e');
      return null;
    }
  }

  /// `#EXTINF` entries for [paths]: from the library when the song is in it,
  /// otherwise the info already stored in [previous].
  Future<List<M3u8Entry>> _entriesFor(
    List<String> paths,
    List<M3u8Entry> previous,
  ) async {
    final songs = <String, SongModel>{
      for (final song
          in await _songRepository?.getSongsByPaths(paths) ??
              const <SongModel>[])
        song.path: song,
    };
    final stored = {for (final entry in previous) entry.path: entry};
    return [
      for (final path in paths)
        if (songs[path] case final song?)
          M3u8Entry(
            path: path,
            durationSeconds: song.durationInSeconds,
            title: '${song.artist} - ${song.title}',
          )
        else
          stored[path] ?? M3u8Entry(path: path),
    ];
  }

  /// Saves [playlist]: the favourites file for Favourites, otherwise the
  /// playlist's own file.
  Future<void> _write(PlaylistModel playlist) async {
    if (playlist.isFixed) {
      await _favourites.setEntries(
        await _entriesFor(playlist.songPaths, await _favourites.entries()),
      );
      return;
    }

    final file = _fileFor(playlist.id);
    final previous = (await _m3u8.read(file))?.entries ?? <M3u8Entry>[];
    await _m3u8.write(
      file,
      M3u8Playlist(
        name: playlist.name,
        createdAt: playlist.createdAt,
        entries: await _entriesFor(playlist.songPaths, previous),
      ),
    );
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    final playlists = <PlaylistModel>[
      for (final file in await _m3u8.list(_directory))
        if (!_isFavouritesFile(file))
          if (await _readFile(file) case final playlist?) playlist,
    ]..sort((a, b) {
      final byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });
    return [await _readFavourites(), ...playlists];
  }

  @override
  Future<PlaylistModel> createPlaylist(String name) => _serialized(() async {
    final trimmed = name.trim();
    for (final playlist in await getPlaylists()) {
      if (playlist.name == trimmed) return playlist;
    }

    final playlist = PlaylistModel(id: await _newId(trimmed), name: trimmed);
    await _write(playlist);
    AppLogger.i('[PlaylistRepository] Created playlist "$trimmed"');
    return playlist;
  });

  /// A file name for a playlist called [name] that is not used yet.
  Future<String> _newId(String name) async {
    var base = name
        .replaceAll(RegExp(r'[/\\\x00-\x1F\x7F:*?"<>|]'), '_')
        .replaceAll(RegExp(r'^\.+'), '')
        .trim();
    if (base.isEmpty) base = 'playlist';
    if (base.length > 100) base = base.substring(0, 100).trim();

    // The favourites file is taken too (e.g. a playlist named
    // "favourites").
    bool taken(String id) => _isFavouritesFile(_fileFor(id));

    var id = base;
    for (var n = 2; taken(id) || await _fileFor(id).exists(); n++) {
      id = '$base ($n)';
    }
    return id;
  }

  @override
  Future<Set<String>> playlistIdsContaining(String songPath) async => {
    for (final playlist in await getPlaylists())
      if (playlist.songPaths.contains(songPath)) playlist.id,
  };

  @override
  Future<void> renamePlaylist(String id, String name) => _serialized(() async {
    final playlist = await _read(id);
    if (playlist == null || playlist.isFixed) return;
    playlist.name = name.trim();
    await _write(playlist);
  });

  @override
  Future<void> setPlaylistSongs(String id, List<String> songPaths) =>
      _serialized(() async {
        final playlist = await _read(id);
        if (playlist == null) return;
        playlist.songPaths = [...songPaths];
        await _write(playlist);
      });

  @override
  Future<void> setSongPlaylists(String songPath, Set<String> playlistIds) =>
      _serialized(() async {
        for (final playlist in await getPlaylists()) {
          // Fixed playlists (Favourites) are changed by their own toggle.
          if (playlist.isFixed) continue;
          final contains = playlist.songPaths.contains(songPath);
          final wanted = playlistIds.contains(playlist.id);
          if (wanted && !contains) {
            playlist.songPaths = [...playlist.songPaths, songPath];
          } else if (!wanted && contains) {
            playlist.songPaths = playlist.songPaths
                .where((p) => p != songPath)
                .toList();
          } else {
            continue;
          }
          await _write(playlist);
        }
        AppLogger.i(
          '[PlaylistRepository] "$songPath" is now in ${playlistIds.length} '
          'playlist(s)',
        );
      });
}
