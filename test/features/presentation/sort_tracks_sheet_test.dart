import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/data/models/song_change.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/sort_tracks_sheet.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgets/widgets.dart';

class MockSongRepository extends Mock implements SongRepository {}

void main() {
  late MockSongRepository repository;
  late SongBloc bloc;

  setUpAll(() => registerFallbackValue(SongSort.title));

  setUp(() {
    repository = MockSongRepository();
    when(
      () => repository.onSongChanged,
    ).thenAnswer((_) => const Stream<SongChange>.empty());
    when(
      () => repository.getSongs(
        after: any(named: 'after'),
        limit: any(named: 'limit'),
        sort: any(named: 'sort'),
      ),
    ).thenAnswer((_) async => []);
    when(() => repository.getSongCount()).thenAnswer((_) async => 0);
    bloc = SongBloc(songRepository: repository);
  });

  tearDown(() => bloc.close());

  /// Opens the sheet from a button, as the app bar does.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MechanixTheme.dark,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SongBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSortTracksSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  MechanixRadio<SongSort> radio(WidgetTester tester, SongSort sort) =>
      tester.widget<MechanixRadio<SongSort>>(
        find.descendant(
          of: find.byKey(ValueKey('sort_tracks_${sort.name}')),
          matching: find.byType(MechanixRadio<SongSort>),
        ),
      );

  testWidgets('shows the current sort', (tester) async {
    bloc.add(const SongSortChanged(SongSort.artist));
    await openSheet(tester);

    expect(radio(tester, SongSort.title).groupValue, SongSort.artist);
  });

  testWidgets('picking a sort reloads the list and closes the sheet', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Date added'));
    await tester.pumpAndSettle();

    expect(find.byType(SortTracksSheet), findsNothing);
    expect(bloc.sort, SongSort.dateAdded);
    verify(
      () => repository.getSongs(
        limit: any(named: 'limit'),
        sort: SongSort.dateAdded,
      ),
    ).called(1);
  });
}
