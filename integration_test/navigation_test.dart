import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_music/features/music/presentation/widgets/playlists/playlists_view.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_controls.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/landing_view.dart';
import 'package:mechanix_music/features/music/presentation/widgets/landing/playing_next.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_bottom_bar.dart';
import 'package:widgets/widgets.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder appBarTitle(String text) => find.descendant(
    of: find.byType(MechanixAppBar),
    matching: find.text(text),
  );

  group('Bottom navigation', () {
    testWidgets('full navigation flow', (tester) async {
      await TestHelper.launchApp(tester); // ← launched ONCE

      // --- Player tab (initial state) ---
      expect(find.byType(MusicBottomBar), findsOneWidget);
      expect(find.byType(MechanixNavigationBar), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(TestHelper.findTab(i), findsOneWidget);
      }
      expect(appBarTitle('MUSIC'), findsOneWidget);
      expect(find.byKey(const ValueKey('music_cast_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('music_search_button')), findsOneWidget);

      // Nothing is playing yet: empty state.
      expect(find.byType(NowPlayingLanding), findsOneWidget);
      expect(find.text('START PLAYING...'), findsOneWidget);
      expect(find.byType(LandingControls), findsOneWidget);
      expect(find.byType(PlayingNext), findsOneWidget);

      // --- All tracks tab ---
      await TestHelper.tapTab(tester, TestHelper.tracksTab);
      expect(appBarTitle('All Tracks'), findsOneWidget);

      // --- Playlists tab ---
      await TestHelper.tapTab(tester, TestHelper.playlistsTab);
      expect(appBarTitle('PLAYLISTS'), findsOneWidget);
      expect(find.byType(PlaylistsView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('create_playlist_button')),
        findsOneWidget,
      );

      // --- Back to Player ---
      await TestHelper.tapTab(tester, TestHelper.nowPlayingTab);
      expect(appBarTitle('MUSIC'), findsOneWidget);
    });
  });
}
