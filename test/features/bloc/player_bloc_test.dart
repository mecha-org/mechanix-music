import 'dart:async';
import 'dart:math';

import 'package:mechanix_music/core/utils/enums.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPlaybackRepository extends Mock implements PlaybackRepository {}

class MockSongBloc extends MockBloc<SongEvent, SongState> implements SongBloc {}

class MockSongRepository extends Mock implements SongRepository {}

SongModel song(String id) => SongModel(
  id: id,
  path: '/$id.mp3',
  title: 'Title $id',
  artist: 'artist-$id',
);

// Shared instances so PlaybackState equality (which compares SongModel by
// identity, as SongModel is not Equatable) is stable across tests.
final list5 = List.generate(5, (i) => song('$i'));
final list10 = List.generate(10, (i) => song('$i'));
final outsider = song('outsider');

void main() {
  late MockPlaybackRepository repo;
  late MockSongBloc songBloc;
  late MockSongRepository songRepo;
  late StreamController<SongState> songStateController;
  late StreamController<Duration> durationController;
  late StreamController<void> completeController;

  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  void configureSongBloc(SongState initial) {
    whenListen(songBloc, songStateController.stream, initialState: initial);
  }

  setUp(() {
    repo = MockPlaybackRepository();
    songBloc = MockSongBloc();
    songRepo = MockSongRepository();
    songStateController = StreamController<SongState>.broadcast();
    durationController = StreamController<Duration>.broadcast();
    completeController = StreamController<void>.broadcast();

    var isPlaying = false;
    when(() => repo.isPlaying).thenAnswer((_) => isPlaying);

    when(
      () => repo.onDurationChanged,
    ).thenAnswer((_) => durationController.stream);
    when(
      () => repo.onSongComplete,
    ).thenAnswer((_) => completeController.stream);
    when(() => repo.play(any())).thenAnswer((_) async {
      isPlaying = true;
    });
    when(() => repo.pause()).thenAnswer((_) async {
      isPlaying = false;
    });
    when(() => repo.resume()).thenAnswer((_) async {
      isPlaying = true;
    });
    when(() => repo.seek(any())).thenAnswer((_) async {});
    when(() => repo.stop()).thenAnswer((_) async {
      isPlaying = false;
    });
    when(() => repo.dispose()).thenAnswer((_) async {});
    when(() => repo.getDuration()).thenAnswer((_) async => null);

    when(() => songBloc.songRepository).thenReturn(songRepo);
    when(() => songRepo.deleteSongByPath(any())).thenAnswer((_) async {});

    configureSongBloc(const SongInitial());
  });

  tearDown(() async {
    await songStateController.close();
    await durationController.close();
    await completeController.close();
  });

  PlaybackBloc buildBloc() => PlaybackBloc(repo, songBloc);

  group('construction', () {
    test('starts with an empty playback list when SongBloc is not loaded', () {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.state.status, PlaybackStatus.initial);
      expect(bloc.state.playbackList, isEmpty);
      expect(bloc.state.song, isNull);
    });

    test('seeds the playback list from a loaded SongBloc', () {
      configureSongBloc(SongLoaded(songs: list5, hasMore: false));

      final bloc = buildBloc();
      addTearDown(bloc.close);

      expect(bloc.state.playbackList, list5);
    });
  });

  group('PlaybackPlay', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'emits [loading, playing] and plays the selected song',
      build: buildBloc,
      seed: () => PlaybackState(playbackList: list5),
      act: (bloc) => bloc.add(PlaybackPlay(list5[2])),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[2],
          playbackList: list5,
          currentIndex: 2,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[2],
          playbackList: list5,
          currentIndex: 2,
        ),
      ],
      verify: (_) => verify(() => repo.play(list5[2].path)).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'uses index -1 when the song is not in the playback list',
      build: buildBloc,
      seed: () => PlaybackState(playbackList: list5),
      act: (bloc) => bloc.add(PlaybackPlay(outsider)),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: outsider,
          playbackList: list5,
          currentIndex: -1,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: outsider,
          playbackList: list5,
          currentIndex: -1,
        ),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits [loading, failure] when the repository throws',
      setUp: () => when(() => repo.play(any())).thenThrow(Exception('boom')),
      build: buildBloc,
      seed: () => PlaybackState(playbackList: list5),
      act: (bloc) => bloc.add(PlaybackPlay(list5[2])),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[2],
          playbackList: list5,
          currentIndex: 2,
        ),
        isA<PlaybackState>()
            .having((s) => s.status, 'status', PlaybackStatus.failure)
            .having((s) => s.errorType, 'errorType', PlaybackErrorType.unknown),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits [loading, failure] and deletes song from repository when file not found occurs',
      setUp: () {
        when(() => repo.play(any())).thenThrow(Exception('File not found'));
      },
      build: buildBloc,
      seed: () => PlaybackState(playbackList: list5),
      act: (bloc) => bloc.add(PlaybackPlay(list5[2])),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[2],
          playbackList: list5,
          currentIndex: 2,
        ),
        isA<PlaybackState>()
            .having((s) => s.status, 'status', PlaybackStatus.failure)
            .having(
              (s) => s.errorType,
              'errorType',
              PlaybackErrorType.fileDeleted,
            ),
      ],
      verify: (_) {
        verify(() => songRepo.deleteSongByPath(list5[2].path)).called(1);
      },
    );
  });

  group('PlaybackPause', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'emits paused on success',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[1],
        playbackList: list5,
        currentIndex: 1,
      ),
      act: (bloc) => bloc.add(const PlaybackPause()),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.paused,
          song: list5[1],
          playbackList: list5,
          currentIndex: 1,
        ),
      ],
      verify: (_) => verify(() => repo.pause()).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when the repository throws',
      setUp: () => when(() => repo.pause()).thenThrow(Exception('pause err')),
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.playing, song: list5[0]),
      act: (bloc) => bloc.add(const PlaybackPause()),
      expect: () => [
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackResume', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'emits playing on success',
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.paused, song: list5[0]),
      act: (bloc) => bloc.add(const PlaybackResume()),
      expect: () => [
        PlaybackState(status: PlaybackStatus.playing, song: list5[0]),
      ],
      verify: (_) => verify(() => repo.resume()).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when the repository throws',
      setUp: () => when(() => repo.resume()).thenThrow(Exception('resume err')),
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.paused, song: list5[0]),
      act: (bloc) => bloc.add(const PlaybackResume()),
      expect: () => [
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackSeek', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'seeks without emitting a new state on success',
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.playing, song: list5[0]),
      act: (bloc) => bloc.add(const PlaybackSeek(Duration(seconds: 30))),
      expect: () => const <PlaybackState>[],
      verify: (_) =>
          verify(() => repo.seek(const Duration(seconds: 30))).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when seeking throws',
      setUp: () =>
          when(() => repo.seek(any())).thenThrow(Exception('seek err')),
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.playing, song: list5[0]),
      act: (bloc) => bloc.add(const PlaybackSeek(Duration(seconds: 30))),
      expect: () => [
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackStop', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'resets to a stopped state on success',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(const PlaybackStop()),
      expect: () => const [PlaybackState(status: PlaybackStatus.stopped)],
      verify: (_) => verify(() => repo.stop()).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when stopping throws',
      setUp: () => when(() => repo.stop()).thenThrow(Exception('stop err')),
      build: buildBloc,
      seed: () => const PlaybackState(status: PlaybackStatus.playing),
      act: (bloc) => bloc.add(const PlaybackStop()),
      expect: () => [
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackPlayNext', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'plays the next song without requesting more when far from the end',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list10[0],
        playbackList: list10,
        currentIndex: 0,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list10[1],
          playbackList: list10,
          currentIndex: 1,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list10[1],
          playbackList: list10,
          currentIndex: 1,
        ),
      ],
      verify: (_) {
        verify(() => repo.play(list10[1].path)).called(1);
        verifyNever(() => songBloc.add(const SongLoadMore()));
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'requests more songs from SongBloc when near the end of the list',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[3],
          playbackList: list5,
          currentIndex: 3,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[3],
          playbackList: list5,
          currentIndex: 3,
        ),
      ],
      verify: (_) => verify(() => songBloc.add(const SongLoadMore())).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'does nothing when there is no next song',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[4],
        playbackList: list5,
        currentIndex: 4,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      expect: () => const <PlaybackState>[],
      verify: (_) => verifyNever(() => repo.play(any())),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when playing the next song throws',
      setUp: () =>
          when(() => repo.play(any())).thenThrow(Exception('next err')),
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list10[0],
        playbackList: list10,
        currentIndex: 0,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list10[1],
          playbackList: list10,
          currentIndex: 1,
        ),
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackPlayPrevious', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'plays the previous song',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayPrevious()),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[1],
          playbackList: list5,
          currentIndex: 1,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[1],
          playbackList: list5,
          currentIndex: 1,
        ),
      ],
      verify: (_) => verify(() => repo.play(list5[1].path)).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'does nothing when there is no previous song',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: list5,
        currentIndex: 0,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayPrevious()),
      expect: () => const <PlaybackState>[],
      verify: (_) => verifyNever(() => repo.play(any())),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'emits failure when playing the previous song throws',
      setUp: () =>
          when(() => repo.play(any())).thenThrow(Exception('prev err')),
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayPrevious()),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[1],
          playbackList: list5,
          currentIndex: 1,
        ),
        isA<PlaybackState>().having(
          (s) => s.status,
          'status',
          PlaybackStatus.failure,
        ),
      ],
    );
  });

  group('PlaybackListUpdated', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'only syncs the list when nothing is playing yet',
      build: buildBloc,
      seed: () => PlaybackState(playbackList: [list5[0]]),
      act: (bloc) => bloc.add(PlaybackListUpdated([list5[0], list5[1]])),
      expect: () => [
        PlaybackState(playbackList: [list5[0], list5[1]]),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'updates the list and corrects the current index when the song remains',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) =>
          bloc.add(PlaybackListUpdated([list5[1], list5[2], list5[4]])),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[2],
          playbackList: [list5[1], list5[2], list5[4]],
          currentIndex: 1,
        ),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'stops playback when the current song is removed from the library',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) =>
          bloc.add(PlaybackLibraryUpdated([list5[0], list5[1], list5[3]])),
      expect: () => const [PlaybackState(status: PlaybackStatus.stopped)],
      verify: (_) => verify(() => repo.stop()).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'a new queue picked by the user keeps the current song playing',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => bloc.add(
        PlaybackListUpdated([list5[0], list5[3]], followsLibrary: false),
      ),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[2],
          playbackList: [list5[0], list5[3]],
          currentIndex: -1,
          followsLibrary: false,
        ),
      ],
      verify: (_) => verifyNever(() => repo.stop()),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'library changes do not replace a playlist queue',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: [list5[0], list5[3]],
        followsLibrary: false,
      ),
      act: (bloc) =>
          songStateController.add(SongLoaded(songs: list10, hasMore: false)),
      wait: const Duration(milliseconds: 50),
      expect: () => const <PlaybackState>[],
    );
  });

  group('PlaybackDurationUpdated', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'updates the song duration',
      build: buildBloc,
      seed: () => PlaybackState(status: PlaybackStatus.playing, song: list5[0]),
      act: (bloc) =>
          bloc.add(const PlaybackDurationUpdated(Duration(minutes: 3))),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[0],
          songDuration: const Duration(minutes: 3),
        ),
      ],
    );
  });

  group('SongBloc stream subscription', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'syncs the playback list when SongBloc emits SongLoaded',
      build: buildBloc,
      act: (bloc) =>
          songStateController.add(SongLoaded(songs: list5, hasMore: false)),
      wait: const Duration(milliseconds: 50),
      expect: () => [PlaybackState(playbackList: list5)],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'ignores non-loaded SongBloc states',
      build: buildBloc,
      act: (bloc) => songStateController.add(const SongLoading()),
      wait: const Duration(milliseconds: 50),
      expect: () => const <PlaybackState>[],
    );
  });

  group('onSongComplete stream subscription', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'plays the next song when one is available',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
      ),
      act: (bloc) => completeController.add(null),
      wait: const Duration(milliseconds: 450),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.loading,
          song: list5[3],
          playbackList: list5,
          currentIndex: 3,
        ),
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[3],
          playbackList: list5,
          currentIndex: 3,
        ),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'pauses when there is no next song',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[4],
        playbackList: list5,
        currentIndex: 4,
      ),
      act: (bloc) => completeController.add(null),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.paused,
          song: list5[4],
          playbackList: list5,
          currentIndex: 4,
        ),
      ],
      verify: (_) => verify(() => repo.pause()).called(1),
    );
  });

  group('onDurationChanged stream subscription', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'updates duration immediately when a valid value arrives',
      build: buildBloc,
      act: (bloc) => durationController.add(const Duration(seconds: 200)),
      wait: const Duration(milliseconds: 50),
      expect: () => [const PlaybackState(songDuration: Duration(seconds: 200))],
    );
  });

  group('close', () {
    test(
      'cancels the SongBloc subscription and disposes the repository',
      () async {
        final bloc = buildBloc();

        await bloc.close();

        verify(() => repo.dispose()).called(1);
        expect(bloc.isClosed, isTrue);
      },
    );
  });

  group('repeat mode', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'cycles off → all → one → off',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const PlaybackCycleRepeatMode())
        ..add(const PlaybackCycleRepeatMode())
        ..add(const PlaybackCycleRepeatMode()),
      expect: () => const [
        PlaybackState(repeatMode: RepeatMode.all),
        PlaybackState(repeatMode: RepeatMode.one),
        PlaybackState(),
      ],
    );

    test('repeat all wraps next to the first song at the end', () {
      final state = PlaybackState(
        song: list5[4],
        playbackList: list5,
        currentIndex: 4,
        repeatMode: RepeatMode.all,
      );
      expect(state.hasNext, isTrue);
      expect(state.nextSong, list5[0]);

      final noRepeat = state.copyWith(repeatMode: RepeatMode.off);
      expect(noRepeat.hasNext, isFalse);
      expect(noRepeat.nextSong, isNull);
    });

    blocTest<PlaybackBloc, PlaybackState>(
      'PlaybackPlayNext with repeat all plays the first song after the last',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[4],
        playbackList: list5,
        currentIndex: 4,
        repeatMode: RepeatMode.all,
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      wait: const Duration(milliseconds: 450),
      verify: (_) => verify(() => repo.play(list5[0].path)).called(1),
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'repeat one replays the current song when it completes',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
        repeatMode: RepeatMode.one,
      ),
      act: (_) => completeController.add(null),
      wait: const Duration(milliseconds: 450),
      verify: (_) {
        verify(() => repo.play(list5[2].path)).called(1);
        verifyNever(() => repo.play(list5[3].path));
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'stopping keeps the repeat and shuffle modes',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[2],
        playbackList: list5,
        currentIndex: 2,
        repeatMode: RepeatMode.all,
        isShuffled: true,
        shuffledList: list5,
      ),
      act: (bloc) => bloc.add(const PlaybackStop()),
      expect: () => const [
        PlaybackState(
          status: PlaybackStatus.stopped,
          repeatMode: RepeatMode.all,
          isShuffled: true,
        ),
      ],
    );
  });

  group('shuffle', () {
    PlaybackBloc buildSeeded() =>
        PlaybackBloc(repo, songBloc, random: Random(42));

    blocTest<PlaybackBloc, PlaybackState>(
      'turning shuffle on keeps the current song first and shuffles the rest',
      build: buildSeeded,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list10[3],
        playbackList: list10,
        currentIndex: 3,
      ),
      act: (bloc) => bloc.add(const PlaybackToggleShuffle()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.isShuffled, isTrue);
        expect(state.shuffledList.first, list10[3]);
        expect(
          state.shuffledList.map((s) => s.path).toSet(),
          list10.map((s) => s.path).toSet(),
        );
        expect(state.shuffledList.length, list10.length);
        expect(state.playOrder, state.shuffledList);
        expect(state.upNext, state.shuffledList.sublist(1));
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'turning shuffle off goes back to library order',
      build: buildSeeded,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[1],
        playbackList: list5,
        currentIndex: 1,
        isShuffled: true,
        shuffledList: [list5[1], list5[4], list5[0], list5[3], list5[2]],
      ),
      act: (bloc) => bloc.add(const PlaybackToggleShuffle()),
      expect: () => [
        PlaybackState(
          status: PlaybackStatus.playing,
          song: list5[1],
          playbackList: list5,
          currentIndex: 1,
        ),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'next and previous follow the shuffled order',
      build: buildSeeded,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[4],
        playbackList: list5,
        currentIndex: 4,
        isShuffled: true,
        shuffledList: [list5[1], list5[4], list5[0], list5[3], list5[2]],
      ),
      act: (bloc) => bloc.add(const PlaybackPlayNext()),
      wait: const Duration(milliseconds: 450),
      verify: (bloc) {
        verify(() => repo.play(list5[0].path)).called(1);
        expect(bloc.state.song, list5[0]);
        // Library index is still tracked for when shuffle is turned off.
        expect(bloc.state.currentIndex, 0);
        expect(bloc.state.previousSong, list5[4]);
        expect(bloc.state.nextSong, list5[3]);
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'list updates keep the shuffled order and append new songs',
      build: buildSeeded,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[1],
        playbackList: list5,
        currentIndex: 1,
        isShuffled: true,
        shuffledList: [list5[1], list5[4], list5[0], list5[3], list5[2]],
      ),
      act: (bloc) => bloc.add(PlaybackListUpdated(list10)),
      verify: (bloc) {
        final order = bloc.state.shuffledList;
        expect(order.sublist(0, 5), [
          list10[1],
          list10[4],
          list10[0],
          list10[3],
          list10[2],
        ]);
        expect(
          order.sublist(5).map((s) => s.path).toSet(),
          list10.sublist(5).map((s) => s.path).toSet(),
        );
      },
    );
  });

  group('play next queue', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'queues a song to play right after the current one',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: list5,
        currentIndex: 0,
      ),
      act: (bloc) => bloc
        ..add(PlaybackQueueNext(list5[3]))
        ..add(PlaybackQueueNext(outsider)),
      verify: (bloc) {
        // The most recent "play next" plays first.
        expect(bloc.state.playNextQueue, [outsider, list5[3]]);
        expect(bloc.state.nextSong, outsider);
        expect(bloc.state.upNext.take(3), [outsider, list5[3], list5[1]]);
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'plays queued songs first, then continues after the original song',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: list5,
        currentIndex: 0,
        playNextQueue: [list5[3]],
      ),
      act: (bloc) async {
        bloc.add(const PlaybackPlayNext());
        await Future<void>.delayed(const Duration(milliseconds: 450));
        bloc.add(const PlaybackPlayNext());
      },
      wait: const Duration(milliseconds: 450),
      verify: (bloc) {
        verify(() => repo.play(list5[3].path)).called(1);
        verify(() => repo.play(list5[1].path)).called(1);
        expect(bloc.state.song, list5[1]);
        expect(bloc.state.playNextQueue, isEmpty);
        expect(bloc.state.anchorPath, isNull);
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'starts the song right away when nothing is playing',
      build: buildBloc,
      seed: () => PlaybackState(playbackList: list5),
      act: (bloc) => bloc.add(PlaybackQueueNext(list5[2])),
      wait: const Duration(milliseconds: 450),
      verify: (bloc) {
        verify(() => repo.play(list5[2].path)).called(1);
        expect(bloc.state.playNextQueue, isEmpty);
      },
    );
  });

  group('sleep timer', () {
    blocTest<PlaybackBloc, PlaybackState>(
      'sets and cancels the sleep timer',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const PlaybackSetSleepTimer(SleepTimerOption.minutes15))
        ..add(const PlaybackSetSleepTimer(null)),
      expect: () => const [
        PlaybackState(sleepTimer: SleepTimerOption.minutes15),
        PlaybackState(),
      ],
    );

    blocTest<PlaybackBloc, PlaybackState>(
      'pauses playback when the timer elapses',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: list5,
        sleepTimer: SleepTimerOption.minutes5,
      ),
      act: (bloc) => bloc.add(const PlaybackSleepTimerElapsed()),
      verify: (bloc) {
        verify(() => repo.pause()).called(1);
        expect(bloc.state.sleepTimer, isNull);
        expect(bloc.state.status, PlaybackStatus.paused);
      },
    );

    blocTest<PlaybackBloc, PlaybackState>(
      '"end of track" pauses when the song completes instead of playing next',
      build: buildBloc,
      seed: () => PlaybackState(
        status: PlaybackStatus.playing,
        song: list5[0],
        playbackList: list5,
        sleepTimer: SleepTimerOption.endOfTrack,
      ),
      act: (_) => completeController.add(null),
      wait: const Duration(milliseconds: 450),
      verify: (bloc) {
        verifyNever(() => repo.play(any()));
        verify(() => repo.pause()).called(1);
        expect(bloc.state.sleepTimer, isNull);
      },
    );
  });
}
