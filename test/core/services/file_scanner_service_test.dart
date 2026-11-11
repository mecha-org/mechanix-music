import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/file_scanner_service.dart';

void main() {
  late Directory dir;
  final scanner = FileScannerService();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scanner_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('buildSongModel', () {
    test('returns null for a missing file', () async {
      expect(await scanner.buildSongModel('${dir.path}/nope.mp3'), isNull);
    });

    test('falls back to the file name when there are no tags', () async {
      // Not a real MP3: reading tags fails, the defaults are used.
      final file = File('${dir.path}/My Song.mp3')
        ..writeAsBytesSync(List.filled(64, 0));

      final song = await scanner.buildSongModel(file.path);

      expect(song, isNotNull);
      expect(song!.path, file.path);
      expect(song.title, 'My Song');
      expect(song.artist, 'Unknown Artist');
      expect(song.album, isNull);
      expect(song.artworkBase64, isNull);
      expect(song.id, isNotEmpty);
    });

    test('gives every song a new id', () async {
      final file = File('${dir.path}/a.mp3')..writeAsBytesSync([0, 1, 2]);

      final first = await scanner.buildSongModel(file.path);
      final second = await scanner.buildSongModel(file.path);

      expect(first!.id, isNot(second!.id));
    });
  });

  group('scanDirectory', () {
    test('returns nothing for a missing folder', () async {
      expect(await scanner.scanDirectory('${dir.path}/missing'), isEmpty);
    });

    test('scans only audio files directly in the folder', () async {
      File('${dir.path}/a.mp3').writeAsBytesSync([0, 1, 2]);
      File('${dir.path}/b.FLAC').writeAsBytesSync([0, 1, 2]);
      File('${dir.path}/notes.txt').writeAsStringSync('not music');
      Directory('${dir.path}/sub').createSync();
      File('${dir.path}/sub/c.mp3').writeAsBytesSync([0, 1, 2]);

      final songs = await scanner.scanDirectory(dir.path);

      expect(songs.values.map((s) => s.title).toSet(), {'a', 'b'});
      // Keyed by song id.
      for (final MapEntry(:key, :value) in songs.entries) {
        expect(key, value.id);
      }
    });
  });
}
