import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/mpris/bridge/playback_mpris_bridge.dart';
import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';
import 'package:mechanix_music/features/mpris/data/mpris_artwork_store.dart';
import 'package:mechanix_music/features/mpris/data/server/mpris_server.dart';
import 'package:mechanix_music/features/mpris/mappers/playback_state_mapper.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPlaybackBloc extends MockBloc<PlaybackEvent, PlaybackState>
    implements PlaybackBloc {}

class MockPlaybackRepository extends Mock implements PlaybackRepository {}

class MockMprisServer extends Mock implements MprisServer {}

class FakePlaybackEvent extends Fake implements PlaybackEvent {}

/// Returns a fixed URI for songs whose id starts with "art".
class FakeArtworkStore implements MprisArtworkStore {
  @override
  Uri? uriFor(SongModel song) =>
      song.id.startsWith('art') ? Uri.file('/art/${song.id}.png') : null;
}

SongModel song(String id) => SongModel(
  id: id,
  path: '/music/$id.mp3',
  title: 'Title $id',
  artist: 'Artist $id',
);

final songs = List.generate(3, (i) => song('$i'));

void main() {
  late MockPlaybackBloc bloc;
  late MockPlaybackRepository repository;
  late MockMprisServer server;
  late StreamController<PlaybackState> states;
  late StreamController<Duration> positions;
  late StreamController<void> seeks;
  late PlaybackMprisBridge bridge;

  setUpAll(() {
    registerFallbackValue(FakePlaybackEvent());
    registerFallbackValue(const MprisPlayerState());
    registerFallbackValue(Duration.zero);
  });

  void givenState(PlaybackState state) =>
      whenListen(bloc, states.stream, initialState: state);

  setUp(() {
    bloc = MockPlaybackBloc();
    repository = MockPlaybackRepository();
    server = MockMprisServer();
    states = StreamController<PlaybackState>.broadcast();
    positions = StreamController<Duration>.broadcast();
    seeks = StreamController<void>.broadcast();

    when(
      () => repository.onPositionChanged,
    ).thenAnswer((_) => positions.stream);
    when(() => repository.onSeekComplete).thenAnswer((_) => seeks.stream);
    when(() => repository.getCurrentPosition()).thenAnswer((_) async => null);
    givenState(const PlaybackState());

    bridge = PlaybackMprisBridge(
      playbackBloc: bloc,
      playbackRepository: repository,
      artworkStore: FakeArtworkStore(),
    );
  });

  tearDown(() async {
    await bridge.detach();
    await states.close();
    await positions.close();
    await seeks.close();
  });

  group('state out', () {
    test('attach publishes the current state once', () {
      final state = PlaybackState(
        status: PlaybackStatus.playing,
        song: songs[0],
        playbackList: songs,
      );
      givenState(state);

      bridge.attach(server);

      verify(
        () => server.publish(PlaybackStateMapper.toMpris(state)),
      ).called(1);
    });

    test('each bloc state is published, mapped', () async {
      bridge.attach(server);
      clearInteractions(server);

      final paused = PlaybackState(
        status: PlaybackStatus.paused,
        song: songs[1],
        playbackList: songs,
        currentIndex: 1,
      );
      states.add(paused);
      await pumpEventQueue();

      verify(
        () => server.publish(PlaybackStateMapper.toMpris(paused)),
      ).called(1);
    });

    test('artwork URI is included in the published track', () async {
      bridge.attach(server);
      clearInteractions(server);

      states.add(PlaybackState(song: song('art1')));
      await pumpEventQueue();

      final published =
          verify(() => server.publish(captureAny())).captured.single
              as MprisPlayerState;
      expect(published.track!.artUrl, Uri.file('/art/art1.png'));
    });

    test('onPositionChanged updates position', () async {
      bridge.attach(server);
      positions.add(const Duration(seconds: 42));
      await pumpEventQueue();

      expect(bridge.position, const Duration(seconds: 42));
    });

    test('position resets when the track changes', () async {
      givenState(PlaybackState(song: songs[0]));
      bridge.attach(server);
      positions.add(const Duration(seconds: 42));
      await pumpEventQueue();

      states.add(PlaybackState(song: songs[1]));
      await pumpEventQueue();

      expect(bridge.position, Duration.zero);
    });

    test('onSeekComplete notifies with the player position', () async {
      when(
        () => repository.getCurrentPosition(),
      ).thenAnswer((_) async => const Duration(seconds: 30));
      bridge.attach(server);

      seeks.add(null);
      await pumpEventQueue();

      verify(() => server.notifySeeked(const Duration(seconds: 30))).called(1);
      expect(bridge.position, const Duration(seconds: 30));
    });

    test('onSeekComplete falls back to the cached position', () async {
      bridge.attach(server);
      positions.add(const Duration(seconds: 7));
      await pumpEventQueue();

      seeks.add(null);
      await pumpEventQueue();

      verify(() => server.notifySeeked(const Duration(seconds: 7))).called(1);
    });

    test('detach cancels every subscription', () async {
      bridge.attach(server);
      expect(positions.hasListener, isTrue);
      expect(seeks.hasListener, isTrue);

      await bridge.detach();

      expect(positions.hasListener, isFalse);
      expect(seeks.hasListener, isFalse);

      clearInteractions(server);
      states.add(PlaybackState(song: songs[0]));
      await pumpEventQueue();
      verifyNever(() => server.publish(any()));
    });

    test('attaching twice throws', () {
      bridge.attach(server);
      expect(() => bridge.attach(server), throwsStateError);
    });
  });

  group('commands in', () {
    test('play when paused adds PlaybackResume', () async {
      givenState(
        PlaybackState(status: PlaybackStatus.paused, song: songs[0]),
      );
      await bridge.play();
      verify(() => bloc.add(const PlaybackResume())).called(1);
    });

    test('play with nothing loaded plays list[currentIndex]', () async {
      givenState(PlaybackState(playbackList: songs, currentIndex: 2));
      await bridge.play();
      verify(() => bloc.add(PlaybackPlay(songs[2]))).called(1);
    });

    test('play with an out-of-range index plays the first song', () async {
      givenState(PlaybackState(playbackList: songs, currentIndex: -1));
      await bridge.play();
      verify(() => bloc.add(PlaybackPlay(songs[0]))).called(1);
    });

    test('play with an empty list adds nothing', () async {
      await bridge.play();
      verifyNever(() => bloc.add(any()));
    });

    test('play while playing adds nothing', () async {
      givenState(
        PlaybackState(
          status: PlaybackStatus.playing,
          song: songs[0],
          playbackList: songs,
        ),
      );
      await bridge.play();
      verifyNever(() => bloc.add(any()));
    });

    test('playPause while playing or loading adds PlaybackPause', () async {
      for (final status in [PlaybackStatus.playing, PlaybackStatus.loading]) {
        givenState(PlaybackState(status: status, song: songs[0]));
        await bridge.playPause();
      }
      verify(() => bloc.add(const PlaybackPause())).called(2);
    });

    test('playPause while paused adds PlaybackResume', () async {
      givenState(
        PlaybackState(status: PlaybackStatus.paused, song: songs[0]),
      );
      await bridge.playPause();
      verify(() => bloc.add(const PlaybackResume())).called(1);
    });

    test('pause / stop / next / previous / seekTo add the matching event',
        () async {
      await bridge.pause();
      await bridge.stop();
      await bridge.next();
      await bridge.previous();
      await bridge.seekTo(const Duration(seconds: 12));

      verifyInOrder([
        () => bloc.add(const PlaybackPause()),
        () => bloc.add(const PlaybackStop()),
        () => bloc.add(const PlaybackPlayNext()),
        () => bloc.add(const PlaybackPlayPrevious()),
        () => bloc.add(const PlaybackSeek(Duration(seconds: 12))),
      ]);
    });

    test('a command never calls publish directly', () async {
      bridge.attach(server);
      clearInteractions(server);

      await bridge.pause();
      await bridge.next();
      await bridge.seekTo(const Duration(seconds: 1));

      verifyNever(() => server.publish(any()));
      verifyNever(() => server.notifySeeked(any()));
    });
  });
}
