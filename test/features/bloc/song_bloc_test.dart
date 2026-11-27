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

  // SongModel has no ==: states compare the same song instances.
  final alpha = [song('a', 'Alpha')];

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
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false, totalCount: 2),
      ],
      verify: (_) {
        verify(() => repository.syncInitialSongLibrary()).called(1);
        verify(() => repository.getSongs(limit: 20)).called(1);
      },
    );

    blocTest<SongBloc, SongState>(
      'loads cache immediately, runs sync in background, and reloads on changes',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => true);
        when(
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false, totalCount: 2),
      ],
      verify: (_) {
        verify(() => repository.syncInitialSongLibrary()).called(1);
        // Initial load + post-sync reload = 2 calls
        verify(() => repository.getSongs(limit: 20)).called(2);
      },
    );

    blocTest<SongBloc, SongState>(
      'reloads the first page when SongSyncCompleted is added',
      setUp: () {
        when(
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      seed: () => const SongLoaded(songs: [], hasMore: false),
      act: (bloc) => bloc.add(const SongSyncCompleted()),
      expect: () => [SongLoaded(songs: page, hasMore: false, totalCount: 2)],
      verify: (_) {
        verify(() => repository.getSongs(limit: 20)).called(1);
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
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => fullPage);
        when(() => repository.getSongCount()).thenAnswer((_) async => 50);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: fullPage, hasMore: true, totalCount: 50),
      ],
    );

    blocTest<SongBloc, SongState>(
      'emits [SongLoading, SongError] when fetching the page throws',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(limit: 20),
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
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => page);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const SongInitialized()),
      expect: () => [
        const SongLoading(),
        SongLoaded(songs: page, hasMore: false, totalCount: 2),
      ],
      verify: (_) {
        verify(() => repository.getSongs(limit: 20)).called(1);
      },
    );

    final reinitPage = songs(2);

    blocTest<SongBloc, SongState>(
      're-initializing reloads from the first page',
      setUp: () {
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(limit: 20),
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
        SongLoaded(songs: reinitPage, hasMore: false, totalCount: 2),
        const SongLoading(),
        SongLoaded(songs: reinitPage, hasMore: false, totalCount: 2),
      ],
      verify: (_) {
        verify(() => repository.getSongs(limit: 20)).called(2);
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
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) async => page1);
        when(
          () => repository.getSongs(after: '/19.mp3', limit: 20),
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
        SongLoaded(songs: page1, hasMore: true, totalCount: 40),
        SongLoaded(
          songs: page1,
          hasMore: true,
          isLoadingMore: true,
          totalCount: 40,
        ),
        SongLoaded(songs: [...page1, ...page2], hasMore: false, totalCount: 40),
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
          () => repository.getSongs(after: any(named: 'after'), limit: 20),
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
        hasMore: false,
      ),
      act: (bloc) =>
          bloc.add(SongUpsert(song('1', 'Alpha (edited)', path: '/1.mp3'))),
      expect: () => [
        isA<SongLoaded>()
            .having((s) => s.songs.length, 'length', 1)
            .having((s) => s.songs.single.title, 'title', 'Alpha (edited)'),
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
      'leaves a song past the loaded ones to a later page',
      build: buildBloc,
      seed: () => SongLoaded(songs: [song('a', 'Alpha')], hasMore: true),
      act: (bloc) => bloc.add(SongUpsert(song('z', 'Zulu'))),
      expect: () => const <SongState>[],
    );

    blocTest<SongBloc, SongState>(
      'a song not loaded yet that changes keeps the library size',
      setUp: () =>
          when(() => repository.getSongCount()).thenAnswer((_) async => 5),
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('a', 'Alpha')],
        hasMore: true,
        totalCount: 5,
      ),
      // e.g. favourited elsewhere: an upsert for a song not loaded yet.
      act: (bloc) =>
          bloc.add(SongUpsert(song('z', 'Zulu')..isFavourite = true)),
      expect: () => const <SongState>[],
      verify: (bloc) =>
          expect((bloc.state as SongLoaded).unloadedCount, 4),
    );

    blocTest<SongBloc, SongState>(
      'a new song updates the library size',
      setUp: () =>
          when(() => repository.getSongCount()).thenAnswer((_) async => 6),
      build: buildBloc,
      seed: () => SongLoaded(songs: alpha, hasMore: true, totalCount: 5),
      act: (bloc) => bloc.add(SongUpsert(song('z', 'Zulu'))),
      expect: () => [SongLoaded(songs: alpha, hasMore: true, totalCount: 6)],
    );

    blocTest<SongBloc, SongState>(
      'moves an edited song to its new place',
      build: buildBloc,
      seed: () => SongLoaded(
        songs: [song('a', 'Alpha'), song('b', 'Bravo'), song('c', 'Charlie')],
        hasMore: false,
      ),
      act: (bloc) => bloc.add(SongUpsert(song('a', 'Delta'))),
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
      'a song not loaded yet updates the library size',
      setUp: () =>
          when(() => repository.getSongCount()).thenAnswer((_) async => 4),
      build: buildBloc,
      seed: () => SongLoaded(songs: alpha, hasMore: true, totalCount: 5),
      act: (bloc) => bloc.add(SongDelete(song('z', 'Zulu'))),
      expect: () => [SongLoaded(songs: alpha, hasMore: true, totalCount: 4)],
    );

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

  // Which song the next page starts after.
  group('next page cursor', () {
    void stubInitialPage() {
      when(
        () => repository.syncInitialSongLibrary(),
      ).thenAnswer((_) async => false);
      when(
        () => repository.getSongs(limit: 20),
      ).thenAnswer((_) async => songs(20));
      when(() => repository.getSongCount()).thenAnswer((_) async => 50);
      // Later pages only: `any` would also match the first page (null).
      when(
        () => repository.getSongs(
          after: any(named: 'after', that: isNotNull),
          limit: 20,
        ),
      ).thenAnswer((_) async => songs(3, startIndex: 20));
    }

    Future<void> thenLoadMore(SongBloc bloc, SongEvent change) async {
      bloc.add(const SongInitialized());
      await Future<void>.delayed(Duration.zero);
      bloc.add(change);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SongLoadMore());
      await Future<void>.delayed(Duration.zero);
    }

    blocTest<SongBloc, SongState>(
      'a song inserted before the end leaves the cursor at the last song',
      setUp: stubInitialPage,
      build: buildBloc,
      act: (bloc) =>
          thenLoadMore(bloc, SongUpsert(song('new', 'New', path: '/new.mp3'))),
      verify: (_) => verify(
        () => repository.getSongs(after: '/19.mp3', limit: 20),
      ).called(1),
    );

    blocTest<SongBloc, SongState>(
      'a toggled favourite stays the last song',
      setUp: stubInitialPage,
      build: buildBloc,
      act: (bloc) => thenLoadMore(
        bloc,
        SongUpsert(
          song('19', 'Title 019', path: '/19.mp3')..isFavourite = true,
        ),
      ),
      verify: (_) => verify(
        () => repository.getSongs(after: '/19.mp3', limit: 20),
      ).called(1),
    );

    blocTest<SongBloc, SongState>(
      'a last song renamed to sort later is left to a later page',
      setUp: stubInitialPage,
      build: buildBloc,
      act: (bloc) =>
          thenLoadMore(bloc, SongUpsert(song('19', 'Zulu', path: '/19.mp3'))),
      verify: (_) => verify(
        () => repository.getSongs(after: '/18.mp3', limit: 20),
      ).called(1),
    );

    blocTest<SongBloc, SongState>(
      'after the last song is deleted, pages continue after the one before',
      setUp: stubInitialPage,
      build: buildBloc,
      act: (bloc) => thenLoadMore(
        bloc,
        SongDelete(song('19', 'Title 019', path: '/19.mp3')),
      ),
      verify: (_) => verify(
        () => repository.getSongs(after: '/18.mp3', limit: 20),
      ).called(1),
    );
  });

  group('next page after a song that left the index', () {
    final page1 = songs(20);
    final page2 = songs(3, startIndex: 20);

    blocTest<SongBloc, SongState>(
      'continues after the song before it',
      setUp: () {
        when(
          () => repository.getSongs(after: '/19.mp3', limit: 20),
        ).thenThrow(Exception('no track at /19.mp3'));
        when(
          () => repository.getSongs(after: '/18.mp3', limit: 20),
        ).thenAnswer((_) async => [page1[19], ...page2]);
        when(() => repository.getSongCount()).thenAnswer((_) async => 23);
      },
      build: buildBloc,
      seed: () => SongLoaded(songs: page1, hasMore: true),
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => [
        SongLoaded(songs: page1, hasMore: true, isLoadingMore: true),
        // A song already loaded is not added twice.
        SongLoaded(songs: [...page1, ...page2], hasMore: false, totalCount: 23),
      ],
    );

    blocTest<SongBloc, SongState>(
      'fails after three songs',
      setUp: () {
        when(
          () => repository.getSongs(
            after: any(named: 'after'),
            limit: 20,
          ),
        ).thenThrow(Exception('index broken'));
      },
      build: buildBloc,
      seed: () => SongLoaded(songs: page1, hasMore: true),
      act: (bloc) => bloc.add(const SongLoadMore()),
      expect: () => [
        SongLoaded(songs: page1, hasMore: true, isLoadingMore: true),
        isA<SongError>(),
      ],
      verify: (_) => verify(
        () => repository.getSongs(after: any(named: 'after'), limit: 20),
      ).called(3),
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
      seed: () => SongLoaded(songs: [song('a', 'Alpha')], hasMore: false),
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

  group('sort', () {
    final byTitle = songs(2);
    final byArtist = songs(2).reversed.toList();

    blocTest<SongBloc, SongState>(
      'SongSortChanged shows the sort at once, then reloads in that order',
      setUp: () {
        when(
          () => repository.getSongs(limit: 20, sort: SongSort.artist),
        ).thenAnswer((_) async => byArtist);
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      seed: () => SongLoaded(songs: byTitle, hasMore: true),
      act: (bloc) => bloc.add(const SongSortChanged(SongSort.artist)),
      expect: () => [
        SongLoaded(songs: byTitle, hasMore: false, sort: SongSort.artist),
        SongLoaded(
          songs: byArtist,
          hasMore: false,
          sort: SongSort.artist,
          totalCount: 2,
        ),
      ],
      verify: (bloc) => expect(bloc.sort, SongSort.artist),
    );

    blocTest<SongBloc, SongState>(
      'the songs not loaded yet still count while a new sort loads',
      setUp: () {
        when(
          () => repository.getSongs(limit: 20, sort: SongSort.artist),
        ).thenAnswer((_) async => byArtist);
        when(() => repository.getSongCount()).thenAnswer((_) async => 50);
      },
      build: buildBloc,
      seed: () => SongLoaded(songs: byTitle, hasMore: true, totalCount: 50),
      act: (bloc) => bloc.add(const SongSortChanged(SongSort.artist)),
      expect: () => [
        isA<SongLoaded>()
            .having((s) => s.hasMore, 'hasMore', false)
            .having((s) => s.unloadedCount, 'unloadedCount', 48),
        isA<SongLoaded>().having((s) => s.unloadedCount, 'unloadedCount', 48),
      ],
    );

    blocTest<SongBloc, SongState>(
      'SongSortChanged with the current sort does nothing',
      build: buildBloc,
      seed: () => SongLoaded(songs: byTitle, hasMore: false),
      act: (bloc) => bloc.add(const SongSortChanged(SongSort.title)),
      expect: () => const <SongState>[],
    );

    blocTest<SongBloc, SongState>(
      'drops a page of the previous order that arrives late',
      setUp: () {
        final slowTitlePage = Completer<List<SongModel>>();
        when(
          () => repository.syncInitialSongLibrary(),
        ).thenAnswer((_) async => false);
        when(
          () => repository.getSongs(limit: 20),
        ).thenAnswer((_) => slowTitlePage.future);
        when(
          () => repository.getSongs(limit: 20, sort: SongSort.duration),
        ).thenAnswer((_) async {
          slowTitlePage.complete(byTitle);
          return byArtist;
        });
        when(() => repository.getSongCount()).thenAnswer((_) async => 2);
      },
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SongInitialized());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SongSortChanged(SongSort.duration));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      expect: () => [
        const SongLoading(),
        SongLoaded(
          songs: byArtist,
          hasMore: false,
          sort: SongSort.duration,
          totalCount: 2,
        ),
      ],
    );
  });
}
