import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository_impl.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:mocktail/mocktail.dart';

class MockSongRepository extends Mock implements SongRepository {}

void main() {
  late Directory dir;
  late MockSongRepository songs;
  late PlaylistRepositoryImpl repository;
  late Directory favDir;
  late FavouritesStore favourites;

  /// The user playlists (without the fixed Favourites playlist).
  Future<List<PlaylistModel>> userPlaylists() async => [
    for (final p in await repository.getPlaylists())
      if (!p.isFixed) p,
  ];

  File fileOf(String id) => File('${dir.path}/$id.m3u8');

  setUpAll(() => registerFallbackValue(<String>[]));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('playlists_');
    songs = MockSongRepository();
    when(() => songs.getSongsByPaths(any())).thenAnswer(
      (i) async => [
        for (final path in i.positionalArguments.first as List<String>)
          if (path != '/gone.mp3')
            SongModel(
              id: path,
              path: path,
              title: 'Title of $path',
              artist: 'Artist',
              duration: '01:30',
            ),
      ],
    );
    favDir = await Directory.systemTemp.createTemp('favourites_');
    favourites = FavouritesStore(
      filePathProvider: () => '${favDir.path}/favourites.m3u8',
    );
    repository = PlaylistRepositoryImpl(
      playlistsDirectoryProvider: () => dir.path,
      songRepository: songs,
      favouritesStore: favourites,
    );
  });

  tearDown(() async {
    await dir.delete(recursive: true);
    await favDir.delete(recursive: true);
  });

  test('no folder means no playlists', () async {
    await dir.delete(recursive: true);
    expect(await userPlaylists(), isEmpty);
    await dir.create();
  });

  test('createPlaylist writes an .m3u8 named after the playlist', () async {
    final created = await repository.createPlaylist('  Road trip  ');

    expect(created.id, 'Road trip');
    expect(created.name, 'Road trip');
    expect(fileOf('Road trip').readAsStringSync(), startsWith('#EXTM3U\n'));

    final playlists = await userPlaylists();
    expect(playlists.single.name, 'Road trip');
    expect(playlists.single.songPaths, isEmpty);
  });

  test('createPlaylist returns the existing playlist for a taken name', () async {
    final first = await repository.createPlaylist('Mix');
    final second = await repository.createPlaylist('Mix');
    expect(second.id, first.id);
    expect(await userPlaylists(), hasLength(1));
  });

  test('unsafe names get a safe, unique file name', () async {
    final a = await repository.createPlaylist('AC/DC: best?');
    expect(a.id, 'AC_DC_ best_');

    // A file that already uses the id (e.g. from another player).
    await fileOf('Chill').writeAsString('#EXTM3U\n#PLAYLIST:Other\n');
    final b = await repository.createPlaylist('Chill');
    expect(b.id, 'Chill (2)');
  });

  test('playlists are listed oldest first', () async {
    await const M3u8Service().write(
      fileOf('b'),
      M3u8Playlist(name: 'Newer', createdAt: DateTime.utc(2026, 2)),
    );
    await const M3u8Service().write(
      fileOf('a'),
      M3u8Playlist(name: 'Older', createdAt: DateTime.utc(2026, 1)),
    );

    expect((await userPlaylists()).map((p) => p.name), [
      'Older',
      'Newer',
    ]);
  });

  test('setPlaylistSongs writes #EXTINF from the library', () async {
    final playlist = await repository.createPlaylist('Mix');

    await repository.setPlaylistSongs(playlist.id, ['/b.mp3', '/a.mp3']);

    final text = fileOf(playlist.id).readAsStringSync();
    expect(
      text,
      contains(
        '#EXTINF:90,Artist - Title of /b.mp3\n/b.mp3\n'
        '#EXTINF:90,Artist - Title of /a.mp3\n/a.mp3\n',
      ),
    );
    expect((await userPlaylists()).single.songPaths, [
      '/b.mp3',
      '/a.mp3',
    ]);
  });

  test('songs missing from the library keep their #EXTINF', () async {
    await fileOf('x').writeAsString(
      '#EXTM3U\n#PLAYLIST:X\n#EXTINF:42,Old - Info\n/gone.mp3\n',
    );

    await repository.setPlaylistSongs('x', ['/gone.mp3', '/a.mp3']);

    expect(
      fileOf('x').readAsStringSync(),
      contains('#EXTINF:42,Old - Info\n/gone.mp3\n'),
    );
  });

  test('renamePlaylist changes the name but keeps the file', () async {
    final playlist = await repository.createPlaylist('Mix');
    await repository.setPlaylistSongs(playlist.id, ['/a.mp3']);

    await repository.renamePlaylist(playlist.id, ' Evening ');

    final renamed = (await userPlaylists()).single;
    expect(renamed.id, playlist.id);
    expect(renamed.name, 'Evening');
    expect(renamed.songPaths, ['/a.mp3']);
  });

  test('setSongPlaylists adds to selected and removes from the rest', () async {
    final a = await repository.createPlaylist('A');
    final b = await repository.createPlaylist('B');
    final c = await repository.createPlaylist('C');
    await repository.setPlaylistSongs(a.id, ['/x.mp3', '/song.mp3']);
    await repository.setPlaylistSongs(b.id, ['/x.mp3']);

    await repository.setSongPlaylists('/song.mp3', {b.id, c.id});

    final byId = {
      for (final p in await userPlaylists()) p.id: p.songPaths,
    };
    expect(byId, {
      'A': ['/x.mp3'],
      'B': ['/x.mp3', '/song.mp3'],
      'C': ['/song.mp3'],
    });
    expect(await repository.playlistIdsContaining('/song.mp3'), {'B', 'C'});
  });

  test('concurrent edits do not overwrite each other', () async {
    final a = await repository.createPlaylist('A');
    await Future.wait([
      repository.setSongPlaylists('/1.mp3', {a.id}),
      repository.setSongPlaylists('/2.mp3', {a.id}),
      repository.renamePlaylist(a.id, 'Renamed'),
    ]);

    final playlist = (await userPlaylists()).single;
    expect(playlist.name, 'Renamed');
    expect(playlist.songPaths, ['/1.mp3', '/2.mp3']);
  });

  group('Favourites', () {
    test('is always listed first, even when empty, and is fixed', () async {
      await repository.createPlaylist('Mix');

      final playlists = await repository.getPlaylists();
      expect(playlists.map((p) => p.id), [PlaylistModel.favouritesId, 'Mix']);
      expect(playlists.first.name, 'Favourites');
      expect(playlists.first.isFixed, isTrue);
      expect(playlists.first.songPaths, isEmpty);
    });

    test('lists the favourite songs and edits the favourites file', () async {
      await favourites.setEntries(const [M3u8Entry(path: '/a.mp3')]);
      expect((await repository.getPlaylists()).first.songPaths, ['/a.mp3']);

      await repository.setPlaylistSongs(PlaylistModel.favouritesId, [
        '/b.mp3',
      ]);
      expect(await favourites.paths(), ['/b.mp3']);
      final entry = (await favourites.entries()).single;
      expect(entry.title, 'Artist - Title of /b.mp3');
    });

    test('is not changed by setSongPlaylists', () async {
      await favourites.setEntries(const [M3u8Entry(path: '/a.mp3')]);
      final mix = await repository.createPlaylist('Mix');

      // Saving the add-to-playlist sheet must not un-favourite the song.
      await repository.setSongPlaylists('/a.mp3', {mix.id});
      expect(await favourites.paths(), ['/a.mp3']);

      // Nor can it favourite one.
      await repository.setSongPlaylists('/b.mp3', {
        PlaylistModel.favouritesId,
      });
      expect(await favourites.paths(), ['/a.mp3']);
    });

    test('cannot be renamed', () async {
      await repository.renamePlaylist(PlaylistModel.favouritesId, 'Other');
      expect((await repository.getPlaylists()).first.name, 'Favourites');
    });

    test('onChanged fires when the favourites change', () async {
      final fired = expectLater(repository.onChanged, emits(anything));
      await favourites.setEntries(const [M3u8Entry(path: '/a.mp3')]);
      await fired;
    });
  });

  test('favourites.m3u8 in the playlists folder is only shown as Favourites',
      () async {
    final store = FavouritesStore(
      filePathProvider: () => '${dir.path}/favourites.m3u8',
    );
    final repo = PlaylistRepositoryImpl(
      playlistsDirectoryProvider: () => dir.path,
      songRepository: songs,
      favouritesStore: store,
    );
    await store.setEntries(const [M3u8Entry(path: '/a.mp3')]);
    final mix = await repo.createPlaylist('favourites');

    final playlists = await repo.getPlaylists();
    expect(playlists.map((p) => p.id), [PlaylistModel.favouritesId, mix.id]);
    expect(playlists.first.songPaths, ['/a.mp3']);
    expect(mix.id, 'favourites (2)');
  });
}
