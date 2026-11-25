import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart' show PlaybackStatus;
import 'package:mechanix_music/core/widgets/music_shortcuts.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mocktail/mocktail.dart';

class MockPlaybackBloc extends MockBloc<PlaybackEvent, PlaybackState>
    implements PlaybackBloc {}

final song = SongModel(id: '1', path: '/1.mp3', title: 'One', artist: 'A');

void main() {
  late MockPlaybackBloc bloc;
  late GlobalKey<NavigatorState> navigatorKey;

  setUpAll(() => registerFallbackValue(const PlaybackPause()));

  setUp(() {
    bloc = MockPlaybackBloc();
    navigatorKey = GlobalKey<NavigatorState>();
  });

  void withState(PlaybackState state) =>
      whenListen(bloc, const Stream<PlaybackState>.empty(), initialState: state);

  Future<void> pumpApp(WidgetTester tester, {Widget? home}) =>
      tester.pumpWidget(
        BlocProvider<PlaybackBloc>.value(
          value: bloc,
          child: MusicShortcuts(
            navigatorKey: navigatorKey,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              shortcuts: MusicShortcuts.appShortcuts,
              home: home ?? const Scaffold(body: Text('main')),
            ),
          ),
        ),
      );

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }

  test('appShortcuts maps Space and ←/→ once, to doing nothing', () {
    for (final key in [
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      final intents = [
        for (final MapEntry(key: activator, :value)
            in MusicShortcuts.appShortcuts.entries)
          if (activator is SingleActivator &&
              activator.trigger == key &&
              !activator.control &&
              !activator.alt &&
              !activator.shift &&
              !activator.meta)
            value,
      ];
      expect(intents, [isA<DoNothingAndStopPropagationIntent>()], reason: '$key');
    }
    // Enter still activates.
    expect(
      MusicShortcuts.appShortcuts.entries.any(
        (e) =>
            e.key is SingleActivator &&
            (e.key as SingleActivator).trigger == LogicalKeyboardKey.enter &&
            e.value is ActivateIntent,
      ),
      isTrue,
    );
  });

  group('Space', () {
    testWidgets('pauses while playing', (tester) async {
      withState(PlaybackState(status: PlaybackStatus.playing, song: song));
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      verify(() => bloc.add(const PlaybackPause())).called(1);
    });

    testWidgets('resumes a paused song', (tester) async {
      withState(PlaybackState(status: PlaybackStatus.paused, song: song));
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      verify(() => bloc.add(const PlaybackResume())).called(1);
    });

    testWidgets('starts the queue when nothing is loaded', (tester) async {
      withState(PlaybackState(playbackList: [song]));
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      verify(() => bloc.add(PlaybackPlay(song))).called(1);
    });

    testWidgets('does not also press the focused button', (tester) async {
      withState(PlaybackState(status: PlaybackStatus.playing, song: song));
      var presses = 0;
      await pumpApp(
        tester,
        home: Scaffold(
          body: TextButton(
            autofocus: true,
            onPressed: () => presses++,
            child: const Text('button'),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      verify(() => bloc.add(const PlaybackPause())).called(1);
      expect(presses, 0);

      // Enter still presses it.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 1);
    });

    testWidgets('types a space in a text field', (tester) async {
      withState(PlaybackState(status: PlaybackStatus.playing, song: song));
      await pumpApp(
        tester,
        home: const Scaffold(body: TextField(autofocus: true)),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

      verifyNever(() => bloc.add(any()));
    });
  });

  group('arrows', () {
    setUp(
      () => withState(
        PlaybackState(status: PlaybackStatus.playing, song: song),
      ),
    );

    testWidgets('→ and ← seek by ten seconds', (tester) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);

      verify(
        () => bloc.add(const PlaybackSeekBy(Duration(seconds: 10))),
      ).called(1);
      verify(
        () => bloc.add(const PlaybackSeekBy(Duration(seconds: -10))),
      ).called(1);
    });

    testWidgets('Ctrl+→ and Ctrl+← change song', (tester) async {
      await pumpApp(tester);

      await ctrl(tester, LogicalKeyboardKey.arrowRight);
      await ctrl(tester, LogicalKeyboardKey.arrowLeft);

      verify(() => bloc.add(const PlaybackPlayNext())).called(1);
      verify(() => bloc.add(const PlaybackPlayPrevious())).called(1);
    });
  });

  group('Esc', () {
    setUp(() => withState(const PlaybackState()));

    testWidgets('closes the open page', (tester) async {
      await pumpApp(tester);
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('page')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('page'), findsNothing);
      expect(find.text('main'), findsOneWidget);
    });

    testWidgets('does nothing on the main screen', (tester) async {
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('main'), findsOneWidget);
    });
  });
}
