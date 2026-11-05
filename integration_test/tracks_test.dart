import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/all_tracks_tile.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/sleep_timer_sheet.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/add_to_playlist_sheet.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_mini_player.dart';
import 'package:widgets/widgets.dart';

import 'test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Swipes [tile] left to reveal its menu button and opens the menu.
  Future<void> openTrackMenu(WidgetTester tester, Finder tile) async {
    await tester.drag(tile, const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 600));
    final menuButton = find.descendant(
      of: tile,
      matching: find.byType(MechanixIconButton),
    );
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('All tracks tab', () {
    testWidgets('full tracks flow', (tester) async {
      // ── Launch & open All tracks ──────────────────────────────────────────
      await TestHelper.launchApp(tester);
      await TestHelper.waitForTracks(tester);

      expect(find.text('All Tracks'), findsOneWidget);

      // ── Empty library path ────────────────────────────────────────────────
      if (!TestHelper.tracksAreLoaded()) {
        expect(find.text('No music tracks available'), findsOneWidget);
        return;
      }

      // ── Tap a track → it plays in place and the mini player shows ────────
      final firstTrack = find.byType(AllTracksTile).first;
      await tester.tap(firstTrack);
      await TestHelper.pumpUntil(
        tester,
        () => find.byType(MusicMiniPlayer).evaluate().isNotEmpty,
        reason: 'mini player after tapping a track',
      );
      expect(find.byType(MusicScreen), findsNothing);

      // ── Swipe → menu with all actions ─────────────────────────────────────
      await openTrackMenu(tester, firstTrack);
      for (final label in [
        'Play next',
        'Add to playlist',
        'Set sleep timer',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.text('Add to favourite').evaluate().isNotEmpty ||
            find.text('Remove from favourite').evaluate().isNotEmpty,
        isTrue,
      );

      // ── Sleep timer sheet ────────────────────────────────────────────────
      await tester.tap(find.text('Set sleep timer'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SleepTimerSheet), findsOneWidget);
      expect(
        find.byType(MechanixRadio<SleepTimerOption>),
        findsNWidgets(SleepTimerOption.values.length),
      );
      expect(find.text('5 minutes'), findsOneWidget);
      expect(find.text('End of track'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sleep_timer_endOfTrack')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SleepTimerSheet), findsNothing);

      // ── Add to playlist sheet: cancel closes it ──────────────────────────
      await openTrackMenu(tester, firstTrack);
      await tester.tap(find.text('Add to playlist'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AddToPlaylistSheet), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add_to_playlist_cancel')));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AddToPlaylistSheet), findsNothing);

      // ── Mini player opens the full player ────────────────────────────────
      await tester.tap(find.byType(MusicMiniPlayer));
      await TestHelper.pumpUntil(
        tester,
        () => find.byType(MusicScreen).evaluate().isNotEmpty,
        reason: 'player screen from the mini player',
      );
      await tester.pump(const Duration(milliseconds: 600));

      // ── Pause before leaving — stops position updates ─────────────────────
      // final pauseBtn = TestHelper.findMusicButton('assets/icons/pause.png');
      // if (pauseBtn.evaluate().isNotEmpty) {
      //   await tester.tap(pauseBtn);
      //   await tester.pump(const Duration(milliseconds: 400));
      // }
    });
  });
}
