import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/mpris/data/mpris_artwork_store.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

// The 8-byte PNG signature is enough for the store; it doesn't decode.
final _png = base64Encode([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

SongModel song(String id, {String? artwork}) => SongModel(
  id: id,
  path: '/music/$id.mp3',
  title: id,
  artist: 'a',
  artworkBase64: artwork,
);

void main() {
  late Directory directory;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('mpris_art_test');
  });

  tearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test('writes the artwork and returns a file URI', () {
    final store = FileMprisArtworkStore(directory: directory);

    final uri = store.uriFor(song('1', artwork: _png))!;

    expect(uri.scheme, 'file');
    expect(uri.path, endsWith('.png'));
    expect(File.fromUri(uri).readAsBytesSync(), base64Decode(_png));
  });

  test('returns the same URI for the same song', () {
    final store = FileMprisArtworkStore(directory: directory);
    final s = song('1', artwork: _png);
    expect(store.uriFor(s), store.uriFor(s));
  });

  test('songs without artwork give null', () {
    final store = FileMprisArtworkStore(directory: directory);
    expect(store.uriFor(song('1')), isNull);
    expect(store.uriFor(song('2', artwork: '')), isNull);
  });

  test('keeps only the most recent files', () {
    final store = FileMprisArtworkStore(directory: directory, maxFiles: 1);

    final first = store.uriFor(song('1', artwork: _png))!;
    final second = store.uriFor(song('2', artwork: _png))!;

    expect(File.fromUri(first).existsSync(), isFalse);
    expect(File.fromUri(second).existsSync(), isTrue);
  });
}
