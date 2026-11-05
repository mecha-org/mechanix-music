import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository_impl.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('recent_'));
  tearDown(() => dir.delete(recursive: true));

  RecentSearchRepositoryImpl repository({int limit = 3}) =>
      RecentSearchRepositoryImpl(
        filePathProvider: () => '${dir.path}/recent.m3u8',
        limit: limit,
      );

  test('keeps the newest first, without duplicates, up to the limit', () async {
    final recents = repository();
    for (final path in ['/a.mp3', '/b.mp3', '/c.mp3', '/a.mp3', '/d.mp3']) {
      await recents.add(path);
    }
    expect(await recents.getRecentPaths(), ['/d.mp3', '/a.mp3', '/c.mp3']);

    // Stored as .m3u8 and read back by a new instance.
    expect(
      File('${dir.path}/recent.m3u8').readAsStringSync(),
      startsWith('#EXTM3U\n'),
    );
    expect(await repository().getRecentPaths(), [
      '/d.mp3',
      '/a.mp3',
      '/c.mp3',
    ]);
  });

  test('remove and clear', () async {
    final recents = repository();
    await recents.add('/a.mp3');
    await recents.add('/b.mp3');

    await recents.remove('/a.mp3');
    expect(await recents.getRecentPaths(), ['/b.mp3']);

    await recents.clear();
    expect(await repository().getRecentPaths(), isEmpty);
  });
}
