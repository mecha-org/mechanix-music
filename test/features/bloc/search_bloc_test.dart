import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/bloc/search/search_bloc.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockSongRepository extends Mock implements SongRepository {}

class MockRecentSearchRepository extends Mock
    implements RecentSearchRepository {}

SongModel song(String name) =>
    SongModel(id: name, path: '/m/$name.mp3', title: name, artist: 'Artist');

void main() {
  late MockSongRepository songs;
  late MockRecentSearchRepository recents;

  setUpAll(() => registerFallbackValue(<String>[]));

  setUp(() {
    songs = MockSongRepository();
    recents = MockRecentSearchRepository();
    when(() => recents.add(any())).thenAnswer((_) async {});
    when(() => recents.remove(any())).thenAnswer((_) async {});
    when(() => recents.clear()).thenAnswer((_) async {});
  });

  SearchBloc build() => SearchBloc(
    songRepository: songs,
    recentSearchRepository: recents,
    debounce: Duration.zero,
  );

  blocTest<SearchBloc, SearchState>(
    'SearchStarted loads the recent songs that are still in the library',
    setUp: () {
      when(
        () => recents.getRecentPaths(),
      ).thenAnswer((_) async => ['/m/b.mp3', '/m/gone.mp3']);
      when(
        () => songs.getSongsByPaths(['/m/b.mp3', '/m/gone.mp3']),
      ).thenAnswer((_) async => [song('b')]);
    },
    build: build,
    act: (bloc) => bloc.add(const SearchStarted()),
    expect: () => [
      SearchState(recents: [song('b')]),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'typing searches the library',
    setUp: () => when(
      () => songs.searchSongs('cha'),
    ).thenAnswer((_) async => [song('chasing'), song('chase')]),
    build: build,
    act: (bloc) => bloc.add(const SearchQueryChanged('  cha ')),
    expect: () => [
      const SearchState(query: 'cha', isSearching: true),
      SearchState(query: 'cha', results: [song('chasing'), song('chase')]),
    ],
  );

  blocTest<SearchBloc, SearchState>(
    'only the latest query updates the results',
    setUp: () {
      when(() => songs.searchSongs('a')).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return [song('old')];
      });
      when(() => songs.searchSongs('ab')).thenAnswer((_) async => [song('ab')]);
    },
    build: build,
    act: (bloc) => bloc
      ..add(const SearchQueryChanged('a'))
      ..add(const SearchQueryChanged('ab')),
    wait: const Duration(milliseconds: 60),
    verify: (bloc) =>
        expect(bloc.state.results.map((s) => s.title), ['ab']),
  );

  blocTest<SearchBloc, SearchState>(
    'clearing the text clears the results',
    build: build,
    seed: () => SearchState(query: 'x', results: [song('x')]),
    act: (bloc) => bloc.add(const SearchQueryChanged('')),
    expect: () => [const SearchState()],
    verify: (_) => verifyNever(() => songs.searchSongs(any())),
  );

  blocTest<SearchBloc, SearchState>(
    'opening a song moves it to the top of the recent searches',
    build: build,
    seed: () => SearchState(recents: [song('a'), song('b')]),
    act: (bloc) => bloc.add(SearchSongOpened(song('b'))),
    expect: () => [
      SearchState(recents: [song('b'), song('a')]),
    ],
    verify: (_) => verify(() => recents.add('/m/b.mp3')).called(1),
  );

  blocTest<SearchBloc, SearchState>(
    'removes one recent search, or all of them',
    build: build,
    seed: () => SearchState(recents: [song('a'), song('b')]),
    act: (bloc) => bloc
      ..add(const SearchRecentRemoved('/m/a.mp3'))
      ..add(const SearchRecentsCleared()),
    expect: () => [
      SearchState(recents: [song('b')]),
      const SearchState(),
    ],
    verify: (_) {
      verify(() => recents.remove('/m/a.mp3')).called(1);
      verify(() => recents.clear()).called(1);
    },
  );
}
