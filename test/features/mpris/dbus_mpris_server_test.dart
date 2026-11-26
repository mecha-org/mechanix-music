import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';
import 'package:mechanix_music/features/mpris/data/mpris_controls.dart';
import 'package:mechanix_music/features/mpris/data/server/dbus_mpris_server.dart';
import 'package:mocktail/mocktail.dart';

class MockPlayerControl extends Mock implements MprisPlayerControl {}

class MockApplicationControl extends Mock implements MprisApplicationControl {}

/// Covers the D-Bus value building, which needs no bus. Talking to a real
/// session bus is checked by hand (see TEST_PLAN.md).
void main() {
  late MockApplicationControl application;
  late DBusMprisServer server;

  setUp(() {
    application = MockApplicationControl();
    when(() => application.canRaise).thenReturn(false);
    when(() => application.canQuit).thenReturn(true);
    server = DBusMprisServer(
      player: MockPlayerControl(),
      application: application,
    );
  });

  group('trackPath', () {
    test('keeps letters and digits', () {
      expect(server.trackPath('abc123'), '/org/mechanix/music/track/abc123');
    });

    test('encodes other characters, including "_"', () {
      expect(
        server.trackPath('a-b_c'),
        '/org/mechanix/music/track/a_2db_5fc',
      );
    });

    test('always gives a valid object path', () {
      for (final id in [
        '',
        '550e8400-e29b-41d4-a716-446655440000',
        'ünïcödé/../x',
      ]) {
        expect(() => DBusObjectPath(server.trackPath(id)), returnsNormally);
      }
    });

    test('different ids give different paths', () {
      expect(server.trackPath('a-b'), isNot(server.trackPath('a_b')));
    });
  });

  group('metadata', () {
    test('no track gives the NoTrack id only', () {
      expect(server.metadata(null), {
        'mpris:trackid': DBusObjectPath(DBusMprisServer.noTrackPath),
      });
    });

    test('maps every track field', () {
      final metadata = server.metadata(
        MprisTrack(
          id: '7',
          title: 'Song',
          artists: const ['Artist'],
          album: 'Album',
          length: const Duration(seconds: 2),
          artUrl: Uri.file('/art/7.png'),
          url: Uri.file('/music/7.mp3'),
        ),
      );

      expect(metadata, {
        'mpris:trackid': DBusObjectPath('/org/mechanix/music/track/7'),
        'xesam:title': const DBusString('Song'),
        'xesam:artist': DBusArray.string(const ['Artist']),
        'xesam:album': const DBusString('Album'),
        'mpris:length': const DBusInt64(2000000),
        'mpris:artUrl': const DBusString('file:///art/7.png'),
        'xesam:url': const DBusString('file:///music/7.mp3'),
      });
    });

    test('leaves out unknown optional fields', () {
      final metadata = server.metadata(const MprisTrack(id: '7', title: 'S'));
      expect(metadata.keys, ['mpris:trackid', 'xesam:title']);
    });
  });

  group('properties', () {
    test('player properties follow the published state', () {
      server.publish(
        const MprisPlayerState(
          status: MprisPlaybackStatus.paused,
          track: MprisTrack(id: '1', title: 'T'),
          canGoNext: true,
          canSeek: true,
        ),
      );
      final properties = server.playerProperties();

      expect(properties['PlaybackStatus'], const DBusString('Paused'));
      expect(properties['CanGoNext'], const DBusBoolean(true));
      expect(properties['CanGoPrevious'], const DBusBoolean(false));
      expect(properties['CanSeek'], const DBusBoolean(true));
      expect(properties['CanPause'], const DBusBoolean(true));
      expect(properties['CanControl'], const DBusBoolean(true));
      expect(properties.containsKey('Position'), isFalse);
    });

    test('stopped with no track cannot pause', () {
      final properties = server.playerProperties();
      expect(properties['PlaybackStatus'], const DBusString('Stopped'));
      expect(properties['CanPause'], const DBusBoolean(false));
    });

    test('root properties describe the app', () {
      final properties = server.rootProperties();
      expect(properties['Identity'], const DBusString('Mechanix Music'));
      expect(
        properties['DesktopEntry'],
        const DBusString('org.mechanix.music'),
      );
      expect(properties['CanRaise'], const DBusBoolean(false));
      expect(properties['CanQuit'], const DBusBoolean(true));
      expect(properties['HasTrackList'], const DBusBoolean(false));
    });
  });

  test('is not running before start, and publish/notify are safe', () {
    expect(server.isRunning, isFalse);
    expect(server.busName, isNull);
    server.publish(const MprisPlayerState());
    server.notifySeeked(Duration.zero);
  });
}
