import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPlaylistRepository extends Mock implements PlaylistRepository {}

final created = DateTime.utc(2026, 1, 1);

PlaylistModel model(String id, String name, [List<String> paths = const []]) =>
    PlaylistModel(
      id: id,
      name: name,
      createdAt: created,
      songPaths: [...paths],
    );

Playlist playlist(String id, String name, [List<String> paths = const []]) =>
    Playlist.fromModel(model(id, name, paths));

void main() {
  late MockPlaylistRepository repository;

  setUp(() {
    repository = MockPlaylistRepository();
    when(() => repository.onChanged).thenAnswer((_) => const Stream.empty());
    when(() => repository.renamePlaylist(any(), any())).thenAnswer((_) async {});
    when(() => repository.deletePlaylist(any())).thenAnswer((_) async {});
    when(
      () => repository.setPlaylistSongs(any(), any()),
    ).thenAnswer((_) async {});
  });

  setUpAll(() => registerFallbackValue(<String>[]));

  PlaylistBloc buildBloc() => PlaylistBloc(repository: repository);

  test('starts loading with no playlists', () {
    expect(buildBloc().state, const PlaylistState());
  });

  blocTest<PlaylistBloc, PlaylistState>(
    'PlaylistsRequested loads the playlists',
    setUp: () => when(
      () => repository.getPlaylists(),
    ).thenAnswer((_) async => [model('1', 'Road trip', ['/a.mp3'])]),
    build: buildBloc,
    act: (bloc) => bloc.add(const PlaylistsRequested()),
    expect: () => [
      PlaylistState(
        isLoading: false,
        playlists: [
          playlist('1', 'Road trip', ['/a.mp3']),
        ],
      ),
    ],
  );

  group('create', () {
    blocTest<PlaylistBloc, PlaylistState>(
      'names it "Playlist N" with the first free N and completes with it',
      setUp: () => when(
        () => repository.createPlaylist(any()),
      ).thenAnswer((i) async => model('3', i.positionalArguments.first as String)),
      build: buildBloc,
      seed: () => PlaylistState(
        isLoading: false,
        playlists: [playlist('1', 'Playlist 1'), playlist('2', 'Playlist 3')],
      ),
      act: (bloc) async {
        final completer = Completer<Playlist>();
        bloc.add(PlaylistCreateRequested(created: completer));
        expect((await completer.future).name, 'Playlist 2');
      },
      verify: (bloc) {
        verify(() => repository.createPlaylist('Playlist 2')).called(1);
        expect(bloc.state.playlists.map((p) => p.name), [
          'Playlist 1',
          'Playlist 3',
          'Playlist 2',
        ]);
      },
    );
  });

  group('edits', () {
    final seeded = PlaylistState(
      isLoading: false,
      playlists: [
        playlist('1', 'Mix', ['/a.mp3', '/b.mp3', '/c.mp3']),
      ],
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'rename updates the name and saves it',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const PlaylistRenamed('1', '  Evening  ')),
      expect: () => [
        PlaylistState(
          isLoading: false,
          playlists: [
            playlist('1', 'Evening', ['/a.mp3', '/b.mp3', '/c.mp3']),
          ],
        ),
      ],
      verify: (_) =>
          verify(() => repository.renamePlaylist('1', 'Evening')).called(1),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'delete deletes the playlist, then removes it and completes',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        final done = Completer<void>();
        bloc.add(PlaylistDeleted('1', done: done));
        await done.future;
      },
      expect: () => [const PlaylistState(isLoading: false, playlists: [])],
      verify: (_) => verify(() => repository.deletePlaylist('1')).called(1),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'Favourites cannot be deleted',
      build: buildBloc,
      seed: () => PlaylistState(
        isLoading: false,
        playlists: [
          Playlist.fromModel(
            PlaylistModel(
              id: PlaylistModel.favouritesId,
              name: 'Favourites',
              createdAt: created,
              isFixed: true,
            ),
          ),
        ],
      ),
      act: (bloc) =>
          bloc.add(const PlaylistDeleted(PlaylistModel.favouritesId)),
      expect: () => const <PlaylistState>[],
      verify: (_) => verifyNever(() => repository.deletePlaylist(any())),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'delete keeps the playlist and reports the error when it fails',
      setUp: () => when(
        () => repository.deletePlaylist(any()),
      ).thenThrow(Exception('read-only')),
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) async {
        final done = Completer<void>();
        bloc.add(PlaylistDeleted('1', done: done));
        await expectLater(done.future, throwsA(isA<Exception>()));
      },
      expect: () => const <PlaylistState>[],
      verify: (bloc) => expect(bloc.state.byId('1')?.name, 'Mix'),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'rename ignores a name another playlist has (any case)',
      build: buildBloc,
      seed: () => PlaylistState(
        isLoading: false,
        playlists: [playlist('1', 'Mix'), playlist('2', 'Road trip')],
      ),
      act: (bloc) => bloc.add(const PlaylistRenamed('1', ' road TRIP ')),
      expect: () => const <PlaylistState>[],
      verify: (_) =>
          verifyNever(() => repository.renamePlaylist(any(), any())),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'rename can change only the case of its own name',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const PlaylistRenamed('1', 'MIX')),
      verify: (_) =>
          verify(() => repository.renamePlaylist('1', 'MIX')).called(1),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'ignores an empty name',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const PlaylistRenamed('1', '   ')),
      expect: () => const <PlaylistState>[],
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'adding appends a new song once',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc
        ..add(const PlaylistSongAdded('1', '/d.mp3'))
        ..add(const PlaylistSongAdded('1', '/a.mp3')),
      expect: () => [
        PlaylistState(
          isLoading: false,
          playlists: [
            playlist('1', 'Mix', ['/a.mp3', '/b.mp3', '/c.mp3', '/d.mp3']),
          ],
        ),
      ],
      verify: (_) => verify(
        () => repository.setPlaylistSongs('1', [
          '/a.mp3',
          '/b.mp3',
          '/c.mp3',
          '/d.mp3',
        ]),
      ).called(1),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'removing a song saves the remaining order',
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const PlaylistSongRemoved('1', '/b.mp3')),
      verify: (bloc) {
        expect(bloc.state.byId('1')!.songPaths, ['/a.mp3', '/c.mp3']);
        verify(
          () => repository.setPlaylistSongs('1', ['/a.mp3', '/c.mp3']),
        ).called(1);
      },
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'moving follows the ReorderableList index convention',
      build: buildBloc,
      seed: () => seeded,
      // Drag the first song below the last one.
      act: (bloc) => bloc.add(const PlaylistSongMoved('1', 0, 3)),
      verify: (bloc) =>
          expect(bloc.state.byId('1')!.songPaths, ['/b.mp3', '/c.mp3', '/a.mp3']),
    );

    blocTest<PlaylistBloc, PlaylistState>(
      'reloads the stored playlists when saving fails',
      setUp: () {
        when(
          () => repository.setPlaylistSongs(any(), any()),
        ).thenThrow(Exception('disk full'));
        when(() => repository.getPlaylists()).thenAnswer(
          (_) async => [
            model('1', 'Mix', ['/a.mp3', '/b.mp3', '/c.mp3']),
          ],
        );
      },
      build: buildBloc,
      seed: () => seeded,
      act: (bloc) => bloc.add(const PlaylistSongRemoved('1', '/b.mp3')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.byId('1')!.songPaths, [
        '/a.mp3',
        '/b.mp3',
        '/c.mp3',
      ]),
    );
  });

  group('isNameTaken', () {
    final state = PlaylistState(
      isLoading: false,
      playlists: [playlist('1', 'Mix'), playlist('2', 'Road trip')],
    );

    test('matches other playlists, trimmed and ignoring case', () {
      expect(state.isNameTaken(' ROAD trip '), isTrue);
      expect(state.isNameTaken('Evening'), isFalse);
    });

    test('ignores the playlist being renamed', () {
      expect(state.isNameTaken('mix', exceptId: '1'), isFalse);
      expect(state.isNameTaken('mix', exceptId: '2'), isTrue);
    });
  });
}
