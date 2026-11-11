import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:mechanix_music/features/music/presentation/screens/search_screen.dart';
import 'package:mechanix_music/features/music/presentation/widgets/search/search_header.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Search', () {
    testWidgets('opens from the app bar and goes back', (tester) async {
      await TestHelper.launchApp(tester);

      await tester.tap(find.byKey(const ValueKey('music_search_button')));
      await TestHelper.pumpUntil(
        tester,
        () => find.byType(SearchScreen).evaluate().isNotEmpty,
        reason: 'search screen to open',
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SearchHeader), findsOneWidget);
      expect(find.text('Search tracks, artists or playlist'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('search_back_button')));
      await TestHelper.pumpUntil(
        tester,
        () => find.byType(SearchScreen).evaluate().isEmpty,
        reason: 'search screen to close',
      );
      expect(find.byType(MusicScreen), findsOneWidget);
    });
  });
}
