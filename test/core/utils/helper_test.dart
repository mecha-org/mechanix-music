import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/exceptions/app_exceptions.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/core/utils/helper.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';

void main() {
  group('getMusicDirectory', () {
    test('is the Music folder in the home directory', () {
      final home = Platform.environment['HOME'] ?? '/home';
      expect(getMusicDirectory(), '$home/Music');
    });
  });

  group('songErrorMessage', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('has a message for every error type', () {
      expect(
        songErrorMessage(l10n, SongErrorType.syncFailed),
        l10n.errorSyncFailed,
      );
      expect(
        songErrorMessage(l10n, SongErrorType.loadFailed),
        l10n.errorLoadFailed,
      );
      expect(
        songErrorMessage(l10n, SongErrorType.addSongsFailed),
        l10n.errorAddSongsFailed,
      );
      expect(songErrorMessage(l10n, SongErrorType.unknown), l10n.errorUnknown);
    });
  });

  group('formatDuration', () {
    test('zero is 00:00', () {
      expect(formatDuration(Duration.zero), '00:00');
    });

    test('minutes and seconds are padded', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '03:07');
    });

    test('hours are shown when there are any', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('formatDate', () {
    test('formats as day, short month and year', () {
      expect(formatDate(DateTime(2026, 11, 5), locale: 'en_US'), '5 Nov 2026');
    });

    test('uses the default locale when none is given', () {
      expect(formatDate(DateTime(2026, 1, 9)), contains('2026'));
    });
  });

  group('exceptions', () {
    test('have readable default messages', () {
      expect(
        AppAlreadyRunningException().toString(),
        'This app instance is already running.',
      );
      expect(
        PlaybackException().toString(),
        'An unknown playback error occurred.',
      );
      expect(
        PlaybackFileNotFoundException().toString(),
        'Playback file not found.',
      );
    });

    test('keep a custom message', () {
      expect(AppAlreadyRunningException('busy').toString(), 'busy');
      expect(PlaybackException('boom').toString(), 'boom');
    });
  });
}
