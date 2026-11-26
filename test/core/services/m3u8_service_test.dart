import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/m3u8_service.dart';

void main() {
  group('M3u8Playlist.parse', () {
    test('reads the name, creation time and tracks', () {
      final playlist = M3u8Playlist.parse(
        '﻿#EXTM3U\r\n'
        '#PLAYLIST:Road trip\r\n'
        '#X-MECHANIX-CREATED:2026-11-02T10:00:00.000Z\r\n'
        '#EXTINF:215,Queen - Bohemian Rhapsody\r\n'
        '/music/bohemian.mp3\r\n'
        '\r\n'
        '/music/no_info.flac\r\n',
        baseDirectory: '/playlists',
      );

      expect(playlist.name, 'Road trip');
      expect(playlist.createdAt, DateTime.utc(2026, 11, 2, 10));
      expect(playlist.paths, ['/music/bohemian.mp3', '/music/no_info.flac']);
      expect(playlist.entries.first.durationSeconds, 215);
      expect(playlist.entries.first.title, 'Queen - Bohemian Rhapsody');
      expect(playlist.entries.last.durationSeconds, isNull);
      expect(playlist.entries.last.title, isNull);
    });

    test('resolves relative paths and file URIs, skips streams', () {
      final playlist = M3u8Playlist.parse(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="x",Unknown length\n'
        '../Music/a.mp3\n'
        'file:///home/me/Music/b%20c.mp3\n'
        'https://example.com/stream.mp3\n'
        'sub/d: live.mp3\n',
        baseDirectory: '/home/me/playlists',
      );

      expect(playlist.paths, [
        '/home/me/Music/a.mp3',
        '/home/me/Music/b c.mp3',
        '/home/me/playlists/sub/d: live.mp3',
      ]);
      expect(playlist.entries.first.durationSeconds, isNull);
      expect(playlist.entries.first.title, 'Unknown length');
    });

    test('a file without tags is a nameless list of paths', () {
      final playlist = M3u8Playlist.parse(
        '/a.mp3\n/b.mp3\n',
        baseDirectory: '/',
      );
      expect(playlist.name, isNull);
      expect(playlist.paths, ['/a.mp3', '/b.mp3']);
    });
  });

  test('serialize and parse round-trip', () {
    final original = M3u8Playlist(
      name: 'Line\nbreak',
      createdAt: DateTime.utc(2026, 1, 1),
      entries: const [
        M3u8Entry(path: '/a.mp3', durationSeconds: 61, title: 'A - Song'),
        M3u8Entry(path: '/b.mp3'),
      ],
    );

    final text = original.serialize();
    expect(text, startsWith('#EXTM3U\n#PLAYLIST:Line break\n'));
    expect(text, contains('#EXTINF:61,A - Song\n/a.mp3\n'));
    expect(text, contains('#EXTINF:-1,b\n/b.mp3\n'));

    final parsed = M3u8Playlist.parse(text, baseDirectory: '/');
    expect(parsed.name, 'Line break');
    expect(parsed.createdAt, original.createdAt);
    expect(parsed.paths, ['/a.mp3', '/b.mp3']);
  });

  group('M3u8Service', () {
    late Directory dir;
    const service = M3u8Service();

    setUp(() async => dir = await Directory.systemTemp.createTemp('m3u8_'));
    tearDown(() => dir.delete(recursive: true));

    test('read returns null for a missing file', () async {
      expect(await service.read(File('${dir.path}/missing.m3u8')), isNull);
    });

    test('write creates folders, leaves no temp file and reads back', () async {
      final file = File('${dir.path}/nested/list.m3u8');
      await service.write(
        file,
        const M3u8Playlist(
          name: 'Mix',
          entries: [M3u8Entry(path: '/a.mp3')],
        ),
      );

      expect((await service.read(file))!.paths, ['/a.mp3']);
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('list returns only .m3u8 files', () async {
      for (final name in ['b.m3u8', 'a.M3U8', 'c.txt', 'd.m3u8.tmp']) {
        await File('${dir.path}/$name').create();
      }
      final names = (await service.list(dir))
          .map((f) => f.uri.pathSegments.last)
          .toList();
      expect(names, ['a.M3U8', 'b.m3u8']);
    });
  });
}
