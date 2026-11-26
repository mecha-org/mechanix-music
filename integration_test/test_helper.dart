import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:mechanix_music/features/music/presentation/widgets/music/music_bottom_bar.dart';
import 'package:mechanix_music/features/music/presentation/widgets/all_tracks/all_tracks_tile.dart';
import 'package:mechanix_music/main.dart' as app;

/// Shared helpers for the Mechanix Music integration tests.
///
/// The app boots the *real* Tantivy song index, the music-library scan and the
/// real audio backend, so these tests must run on a device/emulator (or a
/// generated desktop/web target):
///
///   flutter test integration_test/<file>_test.dart -d <device>
///
/// They cannot run on the headless `flutter test` runner because they rely on
/// the app's native plugins (flutter_tantivy, audioplayers, path_provider).
class TestHelper {
  /// Bottom-navigation tab indices (Player / All tracks / Playlist).
  static const int nowPlayingTab = 0;
  static const int tracksTab = 1;

  static const int playlistsTab = 2;

  /// Boots the real app and waits until the [MusicScreen] is on screen.
  static Future<void> launchApp(WidgetTester tester) async {
    app.main();
    await pumpUntil(
      tester,
      () => find.byType(MusicScreen).evaluate().isNotEmpty,
      reason: 'MusicScreen to appear',
    );
  }

  /// Pumps frames until [condition] is satisfied or [timeout] elapses.
  ///
  /// Avoids `pumpAndSettle`, which never returns while the library is loading
  /// (the Tracks tab shows an indefinite [CircularProgressIndicator] and the
  /// player/mini-player run continuous rotation animations).
  static Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 60),
    Duration step = const Duration(milliseconds: 100),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await tester.pump(step);
    }
    if (!condition()) {
      throw TestFailure('Timed out waiting for: ${reason ?? 'condition'}');
    }
  }

  /// Finds an [Image] built from an [AssetImage] whose path is [assetPath].
  static Finder findImageAsset(String assetPath) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == assetPath,
      description: 'Image.asset($assetPath)',
    );
  }

  /// Finds the bottom-navigation destination at [index].
  static Finder findTab(int index) => find.descendant(
    of: find.byKey(const ValueKey('music_navigation_bar')),
    matching: find.byKey(ValueKey('destination_$index')),
  );

  /// Taps a bottom-navigation tab by its index.
  static Future<void> tapTab(WidgetTester tester, int index) async {
    final tab = findTab(index);
    expect(tab, findsOneWidget, reason: 'tab $index should exist');
    await tester.tap(tab);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens the folder browser from the All tracks app bar.
  static Future<void> openBrowse(WidgetTester tester) async {
    await tapTab(tester, tracksTab);
    await tester.tap(find.byKey(const ValueKey('music_browse_button')));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Opens the All tracks tab and waits for it to resolve to either a
  /// populated list or the empty state, i.e. the indefinite spinner has been
  /// replaced. The app starts on the Player tab, where the list is offstage.
  static Future<void> waitForTracks(WidgetTester tester) async {
    await tapTab(tester, tracksTab);
    await pumpUntil(
      tester,
      () =>
          find.byType(AllTracksTile).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('all_tracks_empty')).evaluate().isNotEmpty,
      reason: 'tracks to finish loading',
    );
  }

  /// Whether the Tracks tab currently shows a populated list of songs.
  static bool tracksAreLoaded() =>
      find.byType(AllTracksTile).evaluate().isNotEmpty;

  /// Whether the bottom navigation is currently visible.
  static bool hasBottomBar() =>
      find.byType(MusicBottomBar).evaluate().isNotEmpty;
}
