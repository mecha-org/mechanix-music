import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/playing_next.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockPlaybackBloc extends MockBloc<PlaybackEvent, PlaybackState>
    implements PlaybackBloc {}

final songs = List.generate(
  5,
  (i) => SongModel(id: '$i', path: '/$i.mp3', title: 'Song $i', artist: 'A'),
);

/// Playing [current] of songs 0..4.
PlaybackState playing(int current) => PlaybackState(
  status: PlaybackStatus.playing,
  song: songs[current],
  playbackList: songs,
  currentIndex: current,
);

void main() {
  late MockPlaybackBloc bloc;
  late StreamController<PlaybackState> states;

  setUpAll(() => registerFallbackValue(const PlaybackPause()));

  setUp(() {
    bloc = MockPlaybackBloc();
    states = StreamController<PlaybackState>.broadcast();
    // Playing 1: song 0 played, songs 2, 3 and 4 to come.
    whenListen(bloc, states.stream, initialState: playing(1));
  });

  tearDown(() => states.close());

  Future<void> pumpPlayingNext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MechanixTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<PlaybackBloc>.value(
            value: bloc,
            child: const PlayingNext(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startEditing(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('playing_next_edit')));
    await tester.pumpAndSettle();
  }

  Finder removeButton(int song) =>
      find.byKey(ValueKey('playing_next_remove_${songs[song].path}'));

  testWidgets('only songs to come can be removed', (tester) async {
    await pumpPlayingNext(tester);
    expect(removeButton(2), findsNothing);

    await startEditing(tester);

    expect(removeButton(0), findsNothing); // played
    expect(removeButton(1), findsNothing); // playing
    expect(removeButton(2), findsOneWidget);
  });

  testWidgets('× removes that song from what comes next', (tester) async {
    await pumpPlayingNext(tester);
    await startEditing(tester);

    await tester.tap(removeButton(3));
    await tester.pump();

    // Up next is 2, 3, 4: song 3 is at 1.
    verify(() => bloc.add(const PlaybackQueueRemoved(1))).called(1);
  });

  testWidgets('× can be reached and pressed with the keyboard', (
    tester,
  ) async {
    await pumpPlayingNext(tester);
    await startEditing(tester);

    // Whether focus is on a × (its key starts with playing_next_remove_).
    bool removeFocused() {
      var found = false;
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
        final key = e.widget.key;
        found =
            key is ValueKey<String> &&
            key.value.startsWith('playing_next_remove_');
        return !found;
      });
      return found;
    }
    for (var i = 0; i < 10 && !removeFocused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(removeFocused(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // The first × is song 2's, first to come.
    verify(() => bloc.add(const PlaybackQueueRemoved(0))).called(1);
  });

  testWidgets('drops map to positions in what comes next', (tester) async {
    await pumpPlayingNext(tester);
    await startEditing(tester);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );

    // Positions in the whole list: 0 played, 1 playing, 2..4 to come.
    list.onReorderItem!(4, 2); // song 4 to the front of what comes next
    list.onReorderItem!(2, 3);
    list.onReorderItem!(3, 0); // dropped on a played song: first to come
    list.onReorderItem!(0, 3); // a played song can't move

    expect(verify(() => bloc.add(captureAny())).captured, const [
      PlaybackQueueMoved(2, 0),
      PlaybackQueueMoved(0, 1),
      PlaybackQueueMoved(1, 0),
    ]);
  });

  testWidgets('editing ends when nothing is left to come', (tester) async {
    await pumpPlayingNext(tester);
    await startEditing(tester);
    expect(removeButton(2), findsOneWidget);

    // The last song plays: nothing to edit.
    states.add(playing(4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playing_next_edit')), findsNothing);

    // Songs to come again: not editing until asked.
    states.add(playing(1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playing_next_edit')), findsOneWidget);
    expect(removeButton(2), findsNothing);
  });
}
