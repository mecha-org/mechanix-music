// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

void main() {
  group('SongModel', () {
    test('durationInSeconds reads mm:ss and h:mm:ss', () {
      SongModel withDuration(String? d) =>
          SongModel(id: '1', path: '/1.mp3', title: 't', artist: 'a', duration: d);

      expect(withDuration('03:07').durationInSeconds, 187);
      expect(withDuration('1:00:05').durationInSeconds, 3605);
      expect(withDuration(null).durationInSeconds, isNull);
      expect(withDuration('').durationInSeconds, isNull);
      expect(withDuration('ab:cd').durationInSeconds, isNull);
    });

    test('formatDuration pads minutes and seconds', () {
      expect(SongModel.formatDuration(0), '00:00');
      expect(SongModel.formatDuration(187), '03:07');
      expect(SongModel.formatDuration(3605), '60:05');
    });

    test('toJson and fromJson round-trip the stored fields', () {
      final song = SongModel(
        id: '1',
        path: '/1.mp3',
        title: 'One',
        artist: 'A',
        album: 'Album',
        duration: '01:00',
        artworkBase64: 'AAAA',
        mtime: 5,
        size: 6,
        isExternal: true,
      );

      final copy = SongModel.fromJson(song.toJson());

      expect(copy.toJson(), song.toJson());
      expect(copy.isFavourite, isFalse); // not stored
    });
  });

  group('AudioOutput', () {
    final output = AudioOutput(
      id: 'sink',
      name: 'Speaker',
      kind: AudioOutputKind.bluetooth,
    );

    test('compares by value and is not selected by default', () {
      expect(
        output,
        AudioOutput(id: 'sink', name: 'Speaker', kind: AudioOutputKind.bluetooth),
      );
      expect(output.isSelected, isFalse);
      expect(output.props, ['sink', 'Speaker', AudioOutputKind.bluetooth, false]);
    });

    test('copyWith changes only the given fields', () {
      final selected = output.copyWith(isSelected: true);
      expect(selected.isSelected, isTrue);
      expect(selected.name, 'Speaker');
      expect(output.copyWith(name: 'JBL').name, 'JBL');
      expect(output.copyWith(), output);
    });
  });

  group('Playlist', () {
    test('fromModel copies the model and counts tracks', () {
      final model = PlaylistModel(
        id: 'mix',
        name: 'Mix',
        songPaths: ['/1.mp3', '/2.mp3'],
      );

      final playlist = Playlist.fromModel(model);

      expect(model.trackCount, 2);
      expect(playlist.trackCount, 2);
      expect(playlist.name, 'Mix');
      expect(playlist.isFixed, isFalse);
      expect(playlist.copyWith(name: 'New').name, 'New');
      expect(playlist.copyWith(songPaths: []).trackCount, 0);
    });
  });
}
