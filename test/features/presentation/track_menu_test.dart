import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/track_menu.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockPlaybackBloc extends MockBloc<PlaybackEvent, PlaybackState>
    implements PlaybackBloc {}

final playingSong = SongModel(
  id: 'p',
  path: '/playing.mp3',
  title: 'Playing',
  artist: 'A',
);
final song = SongModel(id: 's', path: '/song.mp3', title: 'Song', artist: 'A');

void main() {
  late MockPlaybackBloc bloc;

  setUpAll(() => registerFallbackValue(const PlaybackPause()));

  setUp(() => bloc = MockPlaybackBloc());

  void withState(PlaybackState state) =>
      whenListen(bloc, const Stream<PlaybackState>.empty(), initialState: state);

  /// Opens the track menu of [song] and picks [label].
  Future<void> pick(WidgetTester tester, String label) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MechanixTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PlaybackBloc>.value(
            value: bloc,
            child: Center(child: TrackMenu(song: song)),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(ValueKey('track_menu_button_${song.path}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    // Menu closed, snackbar shown (its 4 s timer is still running).
    await tester.pumpAndSettle();
  }

  /// Lets the snackbar time out, so no timer is left running.
  Future<void> dismissSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  group('Add to queue', () {
    testWidgets('a song already queued is not added again', (tester) async {
      withState(
        PlaybackState(
          status: PlaybackStatus.playing,
          song: playingSong,
          playNextQueue: [song],
        ),
      );

      await pick(tester, 'Add to queue');

      verifyNever(() => bloc.add(any()));
      expect(find.text('This song is already in queue'), findsOneWidget);
      await dismissSnackbar(tester);
    });

    testWidgets('adds the song and says so', (tester) async {
      withState(
        PlaybackState(status: PlaybackStatus.playing, song: playingSong),
      );

      await pick(tester, 'Add to queue');

      verify(() => bloc.add(PlaybackQueueAdd(song))).called(1);
      expect(find.text('Added to queue: Song'), findsOneWidget);
      await dismissSnackbar(tester);
    });

    testWidgets('with nothing playing, the song starts without a message', (
      tester,
    ) async {
      withState(const PlaybackState());

      await pick(tester, 'Add to queue');

      verify(() => bloc.add(PlaybackQueueAdd(song))).called(1);
      expect(find.textContaining('queue'), findsNothing);
      await dismissSnackbar(tester);
    });
  });

  testWidgets('Play next with nothing playing shows no message', (
    tester,
  ) async {
    withState(const PlaybackState());

    await pick(tester, 'Play next');

    verify(() => bloc.add(PlaybackQueueNext(song))).called(1);
    expect(find.textContaining('Playing next'), findsNothing);
    await dismissSnackbar(tester);
  });
}
