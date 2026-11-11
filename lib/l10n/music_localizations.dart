import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'music_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/music_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @browseMusicFolders.
  ///
  /// In en, this message translates to:
  /// **'Browse music folders'**
  String get browseMusicFolders;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @quickHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get quickHome;

  /// No description provided for @quickRecents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get quickRecents;

  /// No description provided for @quickDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get quickDownloads;

  /// No description provided for @quickDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get quickDocuments;

  /// No description provided for @hardDrive.
  ///
  /// In en, this message translates to:
  /// **'Hard Drive'**
  String get hardDrive;

  /// No description provided for @root.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get root;

  /// No description provided for @browseMusicBreadcrumb.
  ///
  /// In en, this message translates to:
  /// **'Browse music'**
  String get browseMusicBreadcrumb;

  /// No description provided for @localFile.
  ///
  /// In en, this message translates to:
  /// **'Local File'**
  String get localFile;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @noSelection.
  ///
  /// In en, this message translates to:
  /// **'No selection'**
  String get noSelection;

  /// No description provided for @noTracksAvailable.
  ///
  /// In en, this message translates to:
  /// **'No music tracks available'**
  String get noTracksAvailable;

  /// No description provided for @noFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No audio files or folders found'**
  String get noFilesFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tooltipCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get tooltipCancel;

  /// No description provided for @tooltipSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get tooltipSelectAll;

  /// No description provided for @tooltipSave.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get tooltipSave;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(num count);

  /// No description provided for @savingSongs.
  ///
  /// In en, this message translates to:
  /// **'Saving {count} song(s) to library...'**
  String savingSongs(num count);

  /// No description provided for @queuedSongs.
  ///
  /// In en, this message translates to:
  /// **'Queued {count} song(s) for library import'**
  String queuedSongs(num count);

  /// No description provided for @errorSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync the music library.'**
  String get errorSyncFailed;

  /// No description provided for @errorLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tracks.'**
  String get errorLoadFailed;

  /// No description provided for @errorAddSongsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add selected songs.'**
  String get errorAddSongsFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnknown;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @errorPlaybackFileDeleted.
  ///
  /// In en, this message translates to:
  /// **'File is deleted'**
  String get errorPlaybackFileDeleted;

  /// No description provided for @errorPlaybackUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorPlaybackUnknown;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get appTitle;

  /// No description provided for @startPlaying.
  ///
  /// In en, this message translates to:
  /// **'Start playing...'**
  String get startPlaying;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @playingNext.
  ///
  /// In en, this message translates to:
  /// **'Playing next'**
  String get playingNext;

  /// No description provided for @allTracks.
  ///
  /// In en, this message translates to:
  /// **'All Tracks'**
  String get allTracks;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get playNext;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get addToPlaylist;

  /// No description provided for @addToFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourite'**
  String get addToFavourite;

  /// No description provided for @removeFromFavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourite'**
  String get removeFromFavourite;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @setSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Set sleep timer'**
  String get setSleepTimer;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @newPlaylist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get newPlaylist;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @noPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get noPlaylists;

  /// No description provided for @endOfTrack.
  ///
  /// In en, this message translates to:
  /// **'End of track'**
  String get endOfTrack;

  /// No description provided for @filePathCopied.
  ///
  /// In en, this message translates to:
  /// **'File path copied'**
  String get filePathCopied;

  /// No description provided for @playlistsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Playlists updated'**
  String get playlistsUpdated;

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer off'**
  String get sleepTimerOff;

  /// No description provided for @tracksCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tracks'**
  String tracksCount(String count);

  /// No description provided for @minutesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String minutesCount(int count);

  /// No description provided for @playingNextSong.
  ///
  /// In en, this message translates to:
  /// **'Playing next: {title}'**
  String playingNextSong(String title);

  /// No description provided for @sleepTimerSet.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer: {option}'**
  String sleepTimerSet(String option);

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create playlist'**
  String get createPlaylist;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get renamePlaylist;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addTracksTo.
  ///
  /// In en, this message translates to:
  /// **'Add tracks to {name}'**
  String addTracksTo(String name);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tracks, artists or playlist'**
  String get searchHint;

  /// No description provided for @noTracksFound.
  ///
  /// In en, this message translates to:
  /// **'No Tracks Available'**
  String get noTracksFound;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @audioOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio output device'**
  String get audioOutputDevice;

  /// No description provided for @thisDeviceOutput.
  ///
  /// In en, this message translates to:
  /// **'Comet'**
  String get thisDeviceOutput;

  /// No description provided for @noAudioOutputs.
  ///
  /// In en, this message translates to:
  /// **'No audio output devices found'**
  String get noAudioOutputs;

  /// No description provided for @audioOutputFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not switch the audio output'**
  String get audioOutputFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
