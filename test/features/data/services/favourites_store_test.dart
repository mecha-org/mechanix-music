import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late String filePath;

  SongModel song(String name) => SongModel(
    id: name,
    path: '/$name.mp3',
    title: 'Title $name',
    artist: 'Artist',
    duration: '01:30',
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('favourites_store_');
    filePath = p.join(dir.path, 'playlists', 'favourites.m3u8');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('the default location is the playlists folder in the home', () {
    final home = Platform.environment['HOME'] ?? '/home';
    expect(FavouritesStore().filePath, p.join(home, Constants.favouritesFilePath));
  });

  test('set adds and removes songs and fires changes', () async {
    final store = FavouritesStore(filePathProvider: () => filePath);
    var changes = 0;
    final sub = store.changes.listen((_) => changes++);

    await store.set(song('a'), true);
    await store.set(song('b'), true);
    await store.set(song('a'), true); // already a favourite: no change
    await store.set(song('a'), false);
    await pumpEventQueue();

    expect(await store.paths(), ['/b.mp3']);
    expect(changes, 3);
    final entry = (await store.entries()).single;
    expect(entry.durationSeconds, 90);
    expect(entry.title, 'Artist - Title b');
    expect(File(filePath).existsSync(), isTrue);

    await sub.cancel();
    await store.dispose();
  });

  test('a new store reads what an earlier one wrote', () async {
    await FavouritesStore(
      filePathProvider: () => filePath,
    ).setEntries(const [M3u8Entry(path: '/x.mp3')]);

    final reopened = FavouritesStore(filePathProvider: () => filePath);
    expect(await reopened.paths(), ['/x.mp3']);
  });

  test('createdAt is null without a file and set once written', () async {
    final store = FavouritesStore(filePathProvider: () => filePath);
    expect(await store.createdAt(), isNull);

    await store.set(song('a'), true);
    expect(await store.createdAt(), isNotNull);
  });

  test('moves the favourites from the old location', () async {
    final legacy = File(p.join(dir.path, 'favourites.m3u8'))
      ..writeAsStringSync('#EXTM3U\n/old.mp3\n');

    final store = FavouritesStore(
      filePathProvider: () => filePath,
      legacyFilePathProvider: () => legacy.path,
    );

    expect(await store.paths(), ['/old.mp3']);
    expect(legacy.existsSync(), isFalse);
    expect(File(filePath).existsSync(), isTrue);
  });

  test('keeps the new file when both locations exist', () async {
    File(filePath)
      ..createSync(recursive: true)
      ..writeAsStringSync('#EXTM3U\n/new.mp3\n');
    final legacy = File(p.join(dir.path, 'favourites.m3u8'))
      ..writeAsStringSync('#EXTM3U\n/old.mp3\n');

    final store = FavouritesStore(
      filePathProvider: () => filePath,
      legacyFilePathProvider: () => legacy.path,
    );

    expect(await store.paths(), ['/new.mp3']);
    expect(legacy.existsSync(), isTrue);
  });
}
