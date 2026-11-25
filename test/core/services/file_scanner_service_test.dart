import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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

    test('scans audio files in the folder and its subfolders', () async {
      File('${dir.path}/a.mp3').writeAsBytesSync([0, 1, 2]);
      File('${dir.path}/b.FLAC').writeAsBytesSync([0, 1, 2]);
      File('${dir.path}/notes.txt').writeAsStringSync('not music');
      Directory('${dir.path}/Artist/Album').createSync(recursive: true);
      File('${dir.path}/Artist/Album/c.mp3').writeAsBytesSync([0, 1, 2]);
      // Hidden files and folders are skipped.
      File('${dir.path}/.d.mp3').writeAsBytesSync([0, 1, 2]);
      Directory('${dir.path}/.trash').createSync();
      File('${dir.path}/.trash/e.mp3').writeAsBytesSync([0, 1, 2]);

      final songs = await scanner.scanDirectory(dir.path);

      expect(songs.values.map((s) => s.title).toSet(), {'a', 'b', 'c'});
      // Keyed by song id.
      for (final MapEntry(:key, :value) in songs.entries) {
        expect(key, value.id);
      }
    });
  });

  group('makeThumbnail', () {
    test('downscales a big cover to a small JPEG, keeping its shape', () {
      final cover = img.Image(width: 1200, height: 600);
      final thumb = FileScannerService.makeThumbnail(img.encodePng(cover));

      final decoded = img.decodeJpg(base64Decode(thumb!))!;
      expect(decoded.width, FileScannerService.thumbnailSize);
      expect(decoded.height, FileScannerService.thumbnailSize ~/ 2);
    });

    test('keeps a small cover at its size', () {
      final cover = img.Image(width: 100, height: 120);
      final thumb = FileScannerService.makeThumbnail(img.encodePng(cover));

      final decoded = img.decodeJpg(base64Decode(thumb!))!;
      expect((decoded.width, decoded.height), (100, 120));
    });

    test('returns null for bytes that are not an image', () {
      expect(FileScannerService.makeThumbnail([1, 2, 3, 4]), isNull);
    });
  });
}
