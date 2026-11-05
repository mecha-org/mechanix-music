import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockSongRepository extends Mock implements SongRepository {}

SongModel song(String id, String title, {String? path}) => SongModel(
  id: id,
  path: path ?? '/$id.mp3',
  title: title,
  artist: 'artist-$id',
);

List<SongModel> songs(int count, {int startIndex = 0}) =>
    List.generate(count, (i) {
      final n = startIndex + i;
      return song('$n', 'Title ${n.toString().padLeft(3, '0')}');
    });

void main() {
  late MockSongRepository repository;
  late StreamController<SongChange> changeController;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repository = MockSongRepository();
    changeController = StreamController<SongChange>.broadcast();

    // The bloc subscribes to this stream in its constructor.
    when(
      () => repository.onSongChanged,
    ).thenAnswer((_) => changeController.stream);
  });

  tearDown(() async {
    await changeController.close();
  });

  SongBloc buildBloc() => SongBloc(songRepository: repository);

  test('initial state is SongInitial', () {
    expect(buildBloc().state, const SongInitial());
  });

  group('SongInitialized', () {
    final page = songs(2);

    blocTest<SongBloc, SongState>(
      'loads the cache immediately then emits [SongLoading, SongLoaded] with '
      'hasMore false when all songs fit on one page and no changes detected',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false),
      ],
      verify: (_) {
        verify(() => repository.syncInitialSongLibrary()).called(1);
        verify(() => repository.getSongs(offset: 0, limit: 20)).called(1);
      },
    );

    blocTest<SongBloc, SongState>(
      'loads cache immediately, runs sync in background, and reloads on changes',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => true);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false),
      ],
      verify: (_) {
        verify(() => repository.syncInitialSongLibrary()).called(1);
        // Initial load + post-sync reload = 2 calls
        verify(() => repository.getSongs(offset: 0, limit: 20)).called(2);
      },
    );

    blocTest<SongBloc, SongState>(
      'reloads the first page when SongSyncCompleted is added',
      setUp: () {
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      seed: () => const SongLoaded(songs: [], hasMore: false),
      act: (bloc) => bloc.add(const SongSyncCompleted()),
      expect: () => [SongLoaded(songs: page, hasMore: false)],
      verify: (_) {
        verify(() => repository.getSongs(offset: 0, limit: 20)).called(1);
      },
    );

    final fullPage = songs(20);

    blocTest<SongBloc, SongState>(
      'emits hasMore true when total count exceeds the first page',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => fullPage);
        when(() => repository.getSongCount()).thenAnswer((_) async => 50);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: fullPage, hasMore: true),
      ],
    );

    blocTest<SongBloc, SongState>(
      'emits [SongLoading, SongError] when fetching the page throws',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenThrow(Exception('db down'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [const SongLoading(), isA<SongError>()],
    );

    blocTest<SongBloc, SongState>(
      'still loads the first page even when the sync returns false',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false),
      ],
      verify: (_) {
        verify(() => repository.getSongs(offset: 0, limit: 20)).called(1);
      },
    );

    final reinitPage = songs(2);

    blocTest<SongBloc, SongState>(
      're-initializing resets the offset and reloads from the first page',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => reinitPage);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongInitialized());
      },
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: reinitPage, hasMore: false),
        const SongLoading(),
        SongLoaded(songs: reinitPage, hasMore: false),
      ],
      verify: (_) {
        verify(() => repository.getSongs(offset: 0, limit: 20)).called(2);
      },
    );
  });

  group('SongLoadMore', () {
    final page1 = songs(20);
    final page2 = songs(20, startIndex: 20);

    blocTest<SongBloc, SongState>(
      'fetches the next page and appends it, updating hasMore',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => true);
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenAnswer((_) async => page1);
        when(
          () => repository.getSongs(offset: 20, limit: 20),
        ).thenAnswer((_) async => page2);
        when(() => repository.getSongCount()).thenAnswer((_) async => 40);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongLoadMore());
      },
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page1, hasMore: true),
        SongLoaded(songs: page1, hasMore: true, isLoadingMore: true),
        SongLoaded(songs: [...page1, ...page2], hasMore: false),
      ],
    );

    blocTest<SongBloc, SongState>(
      'does nothing when the current state is not SongLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => const <SongState>[],
    );

    blocTest<SongBloc, SongState>(
      'does nothing when there are no more songs',
      build: buildBloc,
      seed: () => SongLoaded(songs: songs(3), hasMore: false),
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => const <SongState>[],
    );

    blocTest<SongBloc, SongState>(
      'does nothing when a load-more is already in progress',
      build: buildBloc,
      seed: () =>
          SongLoaded(songs: songs(3), hasMore: true, isLoadingMore: true),
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => const <SongState>[],
    );

    final loadedSongs = songs(3);

    blocTest<SongBloc, SongState>(
      'emits [loading-more, SongError] when fetching the next page throws',
      setUp: () {
        when(
          () => repository.getSongs(offset: 0, limit: 20),
        ).thenThrow(Exception('page fetch failed'));
      },
      build: buildBloc,
      seed: () => SongLoaded(songs: loadedSongs, hasMore: true),
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => [
        SongLoaded(songs: loadedSongs, hasMore: true, isLoadingMore: true),
        isA<SongError>(),
      ],
    );
  });

  group('SongUpsert', () {
    blocTest<SongBloc, SongState>(
      'replaces an existing song in place when paths match',
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('1', 'Alpha', path: '/1.mp3')],
        hasMore: true,
      ),
      act: (bloc) =>
          bloc.add(SongUpsert(song('1', 'Alpha (edited)', path: '/1.mp3'))),
      expect: () => [
        isA<SongLoaded>()
            .having((s) => s.songs.length, 'length', 1)
            .having((s) => s.songs.single.title, 'title', 'Alpha (edited)')
            .having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<SongBloc, SongState>(
      'inserts a new song sorted by title',
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('b', 'Bravo'), song('d', 'Delta')],
        hasMore: true,
      ),
      act: (bloc) => bloc.add(SongUpsert(song('c', 'Charlie'))),
      expect: () => [
        isA<SongLoaded>().having(
          (s) => s.songs.map((e) => e.title).toList(),
          'titles',
          ['Bravo', 'Charlie', 'Delta'],
        ),
      ],
    );

    blocTest<SongBloc, SongState>(
      'is ignored when the current state is not SongLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(SongUpsert(song('1', 'Alpha'))),
      expect: () => const <SongState>[],
    );
  });

  group('SongDelete', () {
    blocTest<SongBloc, SongState>(
      'removes the song with the matching path',
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('a', 'Alpha'), song('b', 'Bravo')],
        hasMore: true,
      ),
      act: (bloc) => bloc.add(SongDelete(song('a', 'Alpha'))),
      expect: () => [
        isA<SongLoaded>()
            .having((s) => s.songs.map((e) => e.id).toList(), 'ids', ['b'])
            .having((s) => s.hasMore, 'hasMore', true),
      ],
    );

    blocTest<SongBloc, SongState>(
      'is ignored when the current state is not SongLoaded',
      build: buildBloc,
      act: (bloc) => bloc.add(SongDelete(song('a', 'Alpha'))),
      expect: () => const <SongState>[],
    );
  });

  // The bloc keeps an internal `_currentOffset` that upsert (insert) and delete
  // mutate. The only externally observable effect is the offset used by the
  // *next* page fetch, so these tests assert it via the SongLoadMore call.
  group('offset bookkeeping', () {
    void stubInitialPage() {
      when(
        () => repository.syncInitialSongLibrary(),
      ).thenAnswer((_) async => false);
      when(
        () => repository.getSongs(offset: 0, limit: 20),
      ).thenAnswer((_) async => songs(20));
      when(() => repository.getSongCount()).thenAnswer((_) async => 50);
    }

    blocTest<SongBloc, SongState>(
      'inserting a new song bumps the offset used by the next load-more',
      setUp: () {
        stubInitialPage();
        when(
          () => repository.getSongs(offset: 21, limit: 20),
        ).thenAnswer((_) async => songs(3, startIndex: 21));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        // Path not present in the loaded page -> treated as a new insert.
        bloc.add(SongUpsert(song('new', 'New', path: '/new.mp3')));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongLoadMore());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(() => repository.getSongs(offset: 21, limit: 20)).called(1);
      },
    );

    blocTest<SongBloc, SongState>(
      'replacing an existing song leaves the offset unchanged',
      setUp: () {
        stubInitialPage();
        when(
          () => repository.getSongs(offset: 20, limit: 20),
        ).thenAnswer((_) async => songs(3, startIndex: 20));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        // '/5.mp3' is part of songs(20) -> in-place replace, no offset change.
        bloc.add(SongUpsert(song('5', 'Edited', path: '/5.mp3')));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongLoadMore());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(() => repository.getSongs(offset: 20, limit: 20)).called(1);
      },
    );

    blocTest<SongBloc, SongState>(
      'deleting a song decrements the offset used by the next load-more',
      setUp: () {
        stubInitialPage();
        when(
          () => repository.getSongs(offset: 19, limit: 20),
        ).thenAnswer((_) async => songs(3, startIndex: 19));
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        bloc.add(SongDelete(song('5', 'Title 005', path: '/5.mp3')));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongLoadMore());
        await Future<void>.delayed(Duration.zero);
      },
      verify: (_) {
        verify(() => repository.getSongs(offset: 19, limit: 20)).called(1);
      },
    );
  });

  group('SongAddByPaths', () {
    blocTest<SongBloc, SongState>(
      'delegates to the repository and emits no state',
      setUp: () {
        when(() => repository.addSongsByPaths(any())).thenAnswer((_) async {});
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongAddByPaths(['/x.mp3', '/y.mp3'])),
      expect: () => const <SongState>[],
      verify: (_) {
        verify(
          () => repository.addSongsByPaths(['/x.mp3', '/y.mp3']),
        ).called(1);
      },
    );

    blocTest<SongBloc, SongState>(
      'does not call the repository for an empty path list',
      build: buildBloc,
      act: (bloc) => bloc.add(const SongAddByPaths([])),
      expect: () => const <SongState>[],
      verify: (_) {
        verifyNever(() => repository.addSongsByPaths(any()));
      },
    );

    blocTest<SongBloc, SongState>(
      'swallows repository errors without emitting SongError',
      setUp: () {
        when(
          () => repository.addSongsByPaths(any()),
        ).thenThrow(Exception('import failed'));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongAddByPaths(['/x.mp3'])),
      expect: () => const <SongState>[],
      verify: (_) {
        verify(() => repository.addSongsByPaths(['/x.mp3'])).called(1);
      },
    );
  });

  group('repository onSongChanged subscription', () {
    blocTest<SongBloc, SongState>(
      'applies an upsert pushed from the repository stream',
      build: buildBloc,
      seed: () => SongLoaded(songs: [song('a', 'Alpha')], hasMore: true),
      act: (bloc) => changeController.add(
        SongChange(type: SongChangeType.upsert, song: song('z', 'Zulu')),
      ),
      expect: () => [
        isA<SongLoaded>().having(
          (s) => s.songs.map((e) => e.title).toList(),
          'titles',
          ['Alpha', 'Zulu'],
        ),
      ],
    );

    blocTest<SongBloc, SongState>(
      'applies a delete pushed from the repository stream',
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('a', 'Alpha'), song('b', 'Bravo')],
        hasMore: true,
      ),
      act: (bloc) => changeController.add(
        SongChange(type: SongChangeType.delete, song: song('a', 'Alpha')),
      ),
      expect: () => [
        isA<SongLoaded>().having(
          (s) => s.songs.map((e) => e.id).toList(),
          'ids',
          ['b'],
        ),
      ],
    );

    blocTest<SongBloc, SongState>(
      'ignores a stream change while the state is not SongLoaded',
      build: buildBloc,
      act: (bloc) => changeController.add(
        SongChange(type: SongChangeType.upsert, song: song('a', 'Alpha')),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => const <SongState>[],
    );

    test('cancels the onSongChanged subscription on close', () async {
      final bloc = buildBloc();
      await bloc.close();

      // If the subscription were still active, this would call add() on a
      // closed bloc and throw inside the stream callback, failing the test.
      changeController.add(
        SongChange(type: SongChangeType.upsert, song: song('a', 'Alpha')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.isClosed, isTrue);
    });
  });

  group('SongToggleFavourite', () {
    blocTest<SongBloc, SongState>(
      'marks a song as favourite through the repository',
      setUp: () => when(
        () => repository.setFavourite(any(), any()),
      ).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) => bloc.add(SongToggleFavourite(songs(1).first)),
      verify: (_) => verify(
        () => repository.setFavourite(songs(1).first.path, true),
      ).called(1),
    );

    blocTest<SongBloc, SongState>(
      'removes a favourite song from the favourites',
      setUp: () => when(
        () => repository.setFavourite(any(), any()),
      ).thenAnswer((_) async {}),
      build: buildBloc,
      act: (bloc) {
        final song = songs(1).first..isFavourite = true;
        bloc.add(SongToggleFavourite(song));
      },
      verify: (_) => verify(
        () => repository.setFavourite(songs(1).first.path, false),
      ).called(1),
    );
  });
}
