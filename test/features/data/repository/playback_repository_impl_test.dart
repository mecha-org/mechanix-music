import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockAudioPlayer player;
  late PlaybackRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(DeviceFileSource(''));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    player = MockAudioPlayer();
    repository = PlaybackRepositoryImpl(audioPlayer: player);
  });

  group('play', () {
    test('plays a DeviceFileSource built from the given url', () async {
      when(() => player.play(any())).thenAnswer((_) async {});

      final tempFile = File('${Directory.systemTemp.path}/test_song.mp3');
      await tempFile.create();

      try {
        await repository.play(tempFile.path);

        final captured =
            verify(() => player.play(captureAny())).captured.single as Source;
        expect(captured, isA<DeviceFileSource>());
        expect((captured as DeviceFileSource).path, tempFile.path);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });

    test('propagates errors from the player', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_song.mp3');
      await tempFile.create();

      try {
        when(() => player.play(any())).thenThrow(Exception('play failed'));

        expect(repository.play(tempFile.path), throwsException);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    });
  });

  group('pause', () {
    test('delegates to the player', () async {
      when(() => player.pause()).thenAnswer((_) async {});

      await repository.pause();

      verify(() => player.pause()).called(1);
    });

    test('propagates errors from the player', () {
      when(() => player.pause()).thenThrow(Exception('pause failed'));

      expect(repository.pause(), throwsException);
    });
  });

  group('resume', () {
    test('delegates to the player', () async {
      when(() => player.resume()).thenAnswer((_) async {});

      await repository.resume();

      verify(() => player.resume()).called(1);
    });

    test('propagates errors from the player', () {
      when(() => player.resume()).thenThrow(Exception('resume failed'));

      expect(repository.resume(), throwsException);
    });
  });

  group('seek', () {
    test('delegates to the player with the given position', () async {
      when(() => player.seek(any())).thenAnswer((_) async {});

      await repository.seek(const Duration(seconds: 42));

      verify(() => player.seek(const Duration(seconds: 42))).called(1);
    });

    test('propagates errors from the player', () {
      when(() => player.seek(any())).thenThrow(Exception('seek failed'));

      expect(repository.seek(Duration.zero), throwsException);
    });
  });

  group('stop', () {
    test('delegates to the player', () async {
      when(() => player.stop()).thenAnswer((_) async {});

      await repository.stop();

      verify(() => player.stop()).called(1);
    });

    test('propagates errors from the player', () {
      when(() => player.stop()).thenThrow(Exception('stop failed'));

      expect(repository.stop(), throwsException);
    });
  });

  group('dispose', () {
    test('delegates to the player', () async {
      when(() => player.dispose()).thenAnswer((_) async {});

      await repository.dispose();

      verify(() => player.dispose()).called(1);
    });

    test('propagates errors from the player', () {
      when(() => player.dispose()).thenThrow(Exception('dispose failed'));

      expect(repository.dispose(), throwsException);
    });
  });

  group('isPlaying', () {
    test('is true when the player state is playing', () {
      when(() => player.state).thenReturn(PlayerState.playing);

      expect(repository.isPlaying, isTrue);
    });

    test('is false for any non-playing state', () {
      when(() => player.state).thenReturn(PlayerState.paused);
      expect(repository.isPlaying, isFalse);

      when(() => player.state).thenReturn(PlayerState.stopped);
      expect(repository.isPlaying, isFalse);

      when(() => player.state).thenReturn(PlayerState.completed);
      expect(repository.isPlaying, isFalse);
    });
  });

  group('getDuration', () {
    test('returns the duration reported by the player', () async {
      when(
        () => player.getDuration(),
      ).thenAnswer((_) async => const Duration(minutes: 4));

      expect(await repository.getDuration(), const Duration(minutes: 4));
    });

    test('returns null when the player has no duration', () async {
      when(() => player.getDuration()).thenAnswer((_) async => null);

      expect(await repository.getDuration(), isNull);
    });

    test('propagates errors from the player', () {
      when(
        () => player.getDuration(),
      ).thenAnswer((_) => Future<Duration?>.error(Exception('fail')));

      expect(repository.getDuration(), throwsException);
    });
  });

  group('getCurrentPosition', () {
    test('returns the position reported by the player', () async {
      when(
        () => player.getCurrentPosition(),
      ).thenAnswer((_) async => const Duration(seconds: 12));

      expect(
        await repository.getCurrentPosition(),
        const Duration(seconds: 12),
      );
    });

    test('returns null when the player has no position', () async {
      when(() => player.getCurrentPosition()).thenAnswer((_) async => null);

      expect(await repository.getCurrentPosition(), isNull);
    });

    test('propagates errors from the player', () {
      when(
        () => player.getCurrentPosition(),
      ).thenAnswer((_) => Future<Duration?>.error(Exception('fail')));

      expect(repository.getCurrentPosition(), throwsException);
    });
  });

  group('stream getters', () {
    test('onPositionChanged forwards the player stream', () {
      final stream = Stream<Duration>.value(const Duration(seconds: 1));
      when(() => player.onPositionChanged).thenAnswer((_) => stream);

      expect(repository.onPositionChanged, same(stream));
    });

    test('onDurationChanged forwards the player stream', () {
      final stream = Stream<Duration>.value(const Duration(seconds: 2));
      when(() => player.onDurationChanged).thenAnswer((_) => stream);

      expect(repository.onDurationChanged, same(stream));
    });

    test('onSongComplete forwards the player completion stream', () {
      final stream = Stream<void>.value(null);
      when(() => player.onPlayerComplete).thenAnswer((_) => stream);

      expect(repository.onSongComplete, same(stream));
    });

    test('onSeekComplete forwards the player stream', () {
      final stream = Stream<void>.value(null);
      when(() => player.onSeekComplete).thenAnswer((_) => stream);

      expect(repository.onSeekComplete, same(stream));
    });
  });
}
