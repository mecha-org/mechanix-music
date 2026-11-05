import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/file_scanner_service.dart';
import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/data/models/album_summary.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository_impl.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/in_memory_song_index.dart';

class MockFileScannerService extends Mock implements FileScannerService {}

void main() {
  late InMemorySongIndex index;
  late MockFileScannerService scanner;
  late Directory tempConfigDir;
  late Directory tempMusicDir;
  late SongRepositoryImpl repository;

  setUpAll(() {
    // Allow mocktail to use SongModel in `any()`/argument matchers if needed.
    registerFallbackValue(
      SongModel(id: 'fallback', path: '/fallback', title: 't', artist: 'a'),
    );
  });

  String favouritesPath() => '${tempConfigDir.path}/favourites.m3u8';

  setUp(() async {
    index = InMemorySongIndex();
    tempConfigDir = await Directory.systemTemp.createTemp('repo_test_config_');
    scanner = MockFileScannerService();
    tempMusicDir = await Directory.systemTemp.createTemp('repo_test_music_');

    repository = SongRepositoryImpl(
      fileScannerService: scanner,
      songIndex: index,
      favouritesStore: FavouritesStore(filePathProvider: favouritesPath),
      musicDirectoryProvider: () => tempMusicDir.path,
    );
  });

  tearDown(() async {
    await repository.close();
    for (final dir in [tempConfigDir, tempMusicDir]) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  });

  SongModel makeSong(
    String id,
    String path,
    String title, {
    bool isExternal = false,
  }) => SongModel(
    id: id,
    path: path,
    title: title,
    artist: 'artist-$id',
    isExternal: isExternal,
  );

  group('getSongs', () {
    test('returns songs ordered by title', () async {
      index.putAll([
        makeSong('1', '/a.mp3', 'Charlie'),
        makeSong('2', '/b.mp3', 'Alpha'),
        makeSong('3', '/c.mp3', 'Bravo'),
      ]);

      final result = await repository.getSongs(offset: 0, limit: 10);

      expect(result.map((s) => s.title), ['Alpha', 'Bravo', 'Charlie']);
    });

    test('respects offset and limit', () async {
      index.putAll([
        makeSong('1', '/a.mp3', 'Alpha'),
        makeSong('2', '/b.mp3', 'Bravo'),
        makeSong('3', '/c.mp3', 'Charlie'),
        makeSong('4', '/d.mp3', 'Delta'),
      ]);

      final result = await repository.getSongs(offset: 1, limit: 2);

      expect(result.map((s) => s.title), ['Bravo', 'Charlie']);
    });

    test('returns empty list when no songs', () async {
      final result = await repository.getSongs(offset: 0, limit: 10);
      expect(result, isEmpty);
    });
  });

  group('getSongCount', () {
    test('returns the number of stored songs', () async {
      expect(await repository.getSongCount(), 0);

      index.putAll([
        makeSong('1', '/a.mp3', 'Alpha'),
        makeSong('2', '/b.mp3', 'Bravo'),
      ]);

      expect(await repository.getSongCount(), 2);
    });
  });

  group('addSongsByPaths', () {
    test('does nothing for an empty list', () async {
      await repository.addSongsByPaths([]);

      expect(await repository.getSongCount(), 0);
      verifyNever(() => scanner.buildSongModel(any()));
    });

    test('imports new songs and skips already-stored paths', () async {
      index.putAll([makeSong('existing', '/existing.mp3', 'Existing')]);

      when(
        () => scanner.buildSongModel('/new.mp3'),
      ).thenAnswer((_) async => makeSong('new', '/new.mp3', 'New Song'));

      await repository.addSongsByPaths(['/existing.mp3', '/new.mp3']);

      // Scanner should only be asked to build the new path.
      verify(() => scanner.buildSongModel('/new.mp3')).called(1);
      verifyNever(() => scanner.buildSongModel('/existing.mp3'));

      final stored = index.songs.keys.toSet();
      expect(stored, {'/existing.mp3', '/new.mp3'});
    });

    test('emits an upsert change when a song is added', () async {
      when(
        () => scanner.buildSongModel('/new.mp3'),
      ).thenAnswer((_) async => makeSong('new', '/new.mp3', 'New Song'));

      final changes = expectLater(
        repository.onSongChanged,
        emits(
          isA<SongChange>()
              .having((c) => c.type, 'type', SongChangeType.upsert)
              .having((c) => c.song.path, 'path', '/new.mp3'),
        ),
      );

      await repository.addSongsByPaths(['/new.mp3']);
      await changes;
    });

    test('skips paths the scanner cannot build a model for', () async {
      when(
        () => scanner.buildSongModel('/broken.mp3'),
      ).thenAnswer((_) async => null);

      await repository.addSongsByPaths(['/broken.mp3']);

      expect(await repository.getSongCount(), 0);
      verify(() => scanner.buildSongModel('/broken.mp3')).called(1);
    });

    test(
      'correctly marks songs as internal or external based on their path',
      () async {
        final internalPath = '${tempMusicDir.path}/internal.mp3';
        final externalPath = '/some/other/dir/external.mp3';

        when(() => scanner.buildSongModel(internalPath)).thenAnswer(
          (_) async => makeSong('internal', internalPath, 'Internal'),
        );
        when(() => scanner.buildSongModel(externalPath)).thenAnswer(
          (_) async => makeSong('external', externalPath, 'External'),
        );

        await repository.addSongsByPaths([internalPath, externalPath]);

        final [storedInternal, storedExternal] = await repository
            .getSongsByPaths([internalPath, externalPath]);

        expect(storedInternal.isExternal, isFalse);
        expect(storedExternal.isExternal, isTrue);
      },
    );
  });

  group('deleteSongByPath', () {
    test(
      'removes the song from the library and emits a delete change event',
      () async {
        final songPath = '/to_delete.mp3';
        index.putAll([makeSong('to_delete', songPath, 'To Delete')]);

        expect(await repository.getSongCount(), 1);

        final changes = expectLater(
          repository.onSongChanged,
          emits(
            isA<SongChange>()
                .having((c) => c.type, 'type', SongChangeType.delete)
                .having((c) => c.song.path, 'path', songPath),
          ),
        );

        await repository.deleteSongByPath(songPath);
        await changes;

        expect(await repository.getSongCount(), 0);
      },
    );

    test('does nothing if the song does not exist', () async {
      await repository.deleteSongByPath('/non_existent.mp3');
      expect(await repository.getSongCount(), 0);
    });
  });

  group('syncInitialSongLibrary', () {
    test(
      'syncs new files, removes deleted ones, and returns true when changes detected',
      () async {
        final fileStalePath = '${tempMusicDir.path}/stale.mp3';
        index.putAll([makeSong('stale', fileStalePath, 'Stale')]);

        final fileAPath = '${tempMusicDir.path}/a.mp3';
        final fileBPath = '${tempMusicDir.path}/b.mp3';
        await File(fileAPath).create();
        await File(fileBPath).create();

        when(
          () => scanner.buildSongModel(fileAPath),
        ).thenAnswer((_) async => makeSong('a', fileAPath, 'A'));
        when(
          () => scanner.buildSongModel(fileBPath),
        ).thenAnswer((_) async => makeSong('b', fileBPath, 'B'));

        final result = await repository.syncInitialSongLibrary();

        expect(result, isTrue);
        final paths = index.songs.keys.toSet();
        expect(paths, {fileAPath, fileBPath});
      },
    );

    test('returns false when no changes are detected', () async {
      final fileAPath = '${tempMusicDir.path}/a.mp3';
      await File(fileAPath).create();

      final stat = await File(fileAPath).stat();
      final songA = makeSong('a', fileAPath, 'A')
        ..mtime = stat.modified.millisecondsSinceEpoch
        ..size = stat.size;
      index.putAll([songA]);

      final result = await repository.syncInitialSongLibrary();

      expect(result, isFalse);
      expect(index.songs.values.single.path, fileAPath);
    });

    test(
      'clears the library and returns true when music directory does not exist',
      () async {
        index.putAll([makeSong('stale', '/old.mp3', 'Stale')]);
        await tempMusicDir.delete(recursive: true);

        final result = await repository.syncInitialSongLibrary();

        expect(result, isTrue);
        expect(index.songs.values, isEmpty);
      },
    );

    test(
      'preserves custom external songs during folder sync if they still exist on disk',
      () async {
        // 1. Create a dummy external file
        final tempExternalDir = await Directory.systemTemp.createTemp(
          'repo_test_external_',
        );
        final externalFilePath = '${tempExternalDir.path}/custom.mp3';
        final externalFile = File(externalFilePath);
        await externalFile.create();

        // 2. Put it in the DB
        final customSong = makeSong(
          'custom',
          externalFilePath,
          'Custom File',
          isExternal: true,
        );
        index.putAll([customSong]);

        // 3. Put an internal song in DB (which will be deleted since it is not on disk)
        final internalFilePath = '${tempMusicDir.path}/stale.mp3';
        index.putAll([makeSong('stale', internalFilePath, 'Stale')]);

        // 4. Run sync
        final result = await repository.syncInitialSongLibrary();

        // Should return true (since changes were made: 'stale' was deleted)
        expect(result, isTrue);

        // Verify custom file is still in the DB, but stale song is deleted
        final storedPaths = index.songs.keys.toSet();
        expect(storedPaths, {externalFilePath});

        // Cleanup
        await tempExternalDir.delete(recursive: true);
      },
    );

    test(
      'deletes custom external songs during folder sync if they no longer exist on disk',
      () async {
        // 1. Put a missing external file path in DB (without creating it on disk)
        final externalFilePath = '/nonexistent/external_song.mp3';
        final customSong = makeSong(
          'custom',
          externalFilePath,
          'Custom File',
          isExternal: true,
        );
        index.putAll([customSong]);

        // 2. Run sync
        final result = await repository.syncInitialSongLibrary();

        // Should return true (since changes were made: missing custom file deleted)
        expect(result, isTrue);

        // Verify DB is empty
        expect(index.songs.values, isEmpty);
      },
    );
  });

  group('favourites', () {
    test('setFavourite writes the favourites .m3u8 and emits an upsert', () async {
      final song = makeSong('1', '/music/a.mp3', 'Alpha')..duration = '03:05';
      index.putAll([song]);

      final changes = expectLater(
        repository.onSongChanged,
        emits(
          isA<SongChange>()
              .having((c) => c.type, 'type', SongChangeType.upsert)
              .having((c) => c.song.isFavourite, 'isFavourite', isTrue),
        ),
      );
      await repository.setFavourite('/music/a.mp3', true);
      await changes;

      final playlist = await const M3u8Service().read(File(favouritesPath()));
      expect(playlist!.paths, ['/music/a.mp3']);
      expect(playlist.entries.single.durationSeconds, 185);
      expect(playlist.entries.single.title, 'artist-1 - Alpha');
      expect(
        File(favouritesPath()).readAsStringSync(),
        startsWith('#EXTM3U\n'),
      );

      await repository.setFavourite('/music/a.mp3', false);
      expect(
        (await const M3u8Service().read(File(favouritesPath())))!.paths,
        isEmpty,
      );
    });

    test('songs are loaded with isFavourite from the .m3u8 file', () async {
      index.putAll([
        makeSong('1', '/music/a.mp3', 'Alpha'),
        makeSong('2', '/music/b.mp3', 'Bravo'),
      ]);
      await File(favouritesPath()).writeAsString(
        '#EXTM3U\n#EXTINF:-1,Bravo\n/music/b.mp3\n',
      );

      final songs = await repository.getSongs(offset: 0, limit: 10);

      expect(
        {for (final s in songs) s.path: s.isFavourite},
        {'/music/a.mp3': false, '/music/b.mp3': true},
      );
      expect(
        (await repository.getFavouriteSongs()).map((s) => s.path),
        ['/music/b.mp3'],
      );
    });

    test('a rescan keeps the favourite flag of a modified song', () async {
      final path = '${tempMusicDir.path}/a.mp3';
      index.putAll([
        makeSong('a', path, 'A')
          ..lastScannedAt = DateTime.utc(2000)
          ..isFavourite = true,
      ]);
      await File(path).create();
      await File(favouritesPath()).writeAsString('#EXTM3U\n$path\n');
      when(
        () => scanner.buildSongModel(path),
      ).thenAnswer((_) async => makeSong('new-id', path, 'A (remastered)'));

      expect(await repository.syncInitialSongLibrary(), isTrue);

      final song = (await repository.getSongsByPaths([path])).single;
      expect(song.title, 'A (remastered)');
      expect(song.id, 'a', reason: 'the id (artwork name) is kept');
      expect(song.isFavourite, isTrue);
    });
  });

  group('searchSongs', () {
    test('returns library songs matching the query', () async {
      index.putAll([
        makeSong('1', '/music/a.mp3', 'Bohemian Rhapsody'),
        makeSong('2', '/music/b.mp3', 'Hotel California'),
      ]);

      final result = await repository.searchSongs('boh');

      expect(result.map((s) => s.path), ['/music/a.mp3']);
    });

    test('returns nothing for a blank query', () async {
      index.putAll([makeSong('1', '/music/a.mp3', 'Alpha')]);
      expect(await repository.searchSongs('   '), isEmpty);
    });
  });

  group('change detection', () {
    test('a file whose size changed is rescanned', () async {
      final path = '${tempMusicDir.path}/a.mp3';
      await File(path).writeAsString('new content');
      final stat = await File(path).stat();
      index.putAll([
        makeSong('a', path, 'Old')
          ..mtime = stat.modified.millisecondsSinceEpoch
          ..size = stat.size - 1,
      ]);
      when(
        () => scanner.buildSongModel(path),
      ).thenAnswer((_) async => makeSong('other', path, 'New'));

      expect(await repository.syncInitialSongLibrary(), isTrue);

      final stored = index.songs[path]!;
      expect(stored.title, 'New');
      expect(stored.size, stat.size);
      expect(stored.mtime, stat.modified.millisecondsSinceEpoch);
    });
  });

  group('albums', () {
    test('lists albums and their songs', () async {
      index.putAll([
        makeSong('1', '/m/a.mp3', 'Love of My Life')..album = 'Opera',
        makeSong('2', '/m/b.mp3', 'Bohemian Rhapsody')..album = 'Opera',
        makeSong('3', '/m/c.mp3', 'No Album'),
      ]);
      // makeSong uses 'artist-<id>' as the artist.
      for (final song in index.songs.values) {
        song.artist = 'Queen';
      }

      expect(await repository.getAlbums(), [
        const AlbumSummary(artist: 'Queen', album: 'Opera', songCount: 2),
      ]);
      expect(
        (await repository.getAlbumSongs('Queen', 'Opera')).map((s) => s.title),
        ['Bohemian Rhapsody', 'Love of My Life'],
      );
    });
  });
}
