// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'music_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get search => 'Search';

  @override
  String get tracks => 'Tracks';

  @override
  String get browseMusicFolders => 'Browse music folders';

  @override
  String get play => 'Play';

  @override
  String get more => 'More';

  @override
  String get quickHome => 'Home';

  @override
  String get quickRecents => 'Recents';

  @override
  String get quickDownloads => 'Downloads';

  @override
  String get quickDocuments => 'Documents';

  @override
  String get hardDrive => 'Hard Drive';

  @override
  String get root => 'Root';

  @override
  String get browseMusicBreadcrumb => 'Browse music';

  @override
  String get localFile => 'Local File';

  @override
  String get unknown => 'Unknown';

  @override
  String get noSelection => 'No selection';

  @override
  String get noTracksAvailable => 'No music tracks available';

  @override
  String get noFilesFound => 'No audio files or folders found';

  @override
  String get retry => 'Retry';

  @override
  String get tooltipCancel => 'Cancel selection';

  @override
  String get tooltipSelectAll => 'Select all';

  @override
  String get tooltipSave => 'Save to library';

  @override
  String selectedCount(num count) {
    return '$count selected';
  }

  @override
  String savingSongs(num count) {
    return 'Saving $count song(s) to library...';
  }

  @override
  String queuedSongs(num count) {
    return 'Queued $count song(s) for library import';
  }

  @override
  String get errorSyncFailed => 'Failed to sync the music library.';

  @override
  String get errorLoadFailed => 'Failed to load tracks.';

  @override
  String get errorAddSongsFailed => 'Failed to add selected songs.';

  @override
  String get errorUnknown => 'Something went wrong';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get errorPlaybackFileDeleted => 'File is deleted';

  @override
  String get errorPlaybackUnknown => 'Something went wrong';

  @override
  String get appTitle => 'Music';

  @override
  String get startPlaying => 'Start playing...';

  @override
  String get artist => 'Artist';

  @override
  String get playingNext => 'Playing next';

  @override
  String get allTracks => 'All Tracks';

  @override
  String get playlist => 'Playlist';

  @override
  String get playNext => 'Play next';

  @override
  String get addToPlaylist => 'Add to playlist';

  @override
  String get addToFavourite => 'Add to favourite';

  @override
  String get removeFromFavourite => 'Remove from favourite';

  @override
  String get share => 'Share';

  @override
  String get setSleepTimer => 'Set sleep timer';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get newPlaylist => 'New playlist';

  @override
  String get playlistName => 'Playlist name';

  @override
  String get noPlaylists => 'No playlists yet';

  @override
  String get endOfTrack => 'End of track';

  @override
  String get filePathCopied => 'File path copied';

  @override
  String get playlistsUpdated => 'Playlists updated';

  @override
  String get sleepTimerOff => 'Sleep timer off';

  @override
  String tracksCount(String count) {
    return '$count tracks';
  }

  @override
  String minutesCount(int count) {
    return '$count minutes';
  }

  @override
  String playingNextSong(String title) {
    return 'Playing next: $title';
  }

  @override
  String sleepTimerSet(String option) {
    return 'Sleep timer: $option';
  }

  @override
  String get playlists => 'Playlists';

  @override
  String get createPlaylist => 'Create playlist';

  @override
  String get renamePlaylist => 'Rename playlist';

  @override
  String get remove => 'Remove';

  @override
  String addTracksTo(String name) {
    return 'Add tracks to $name';
  }

  @override
  String get searchHint => 'Search tracks, artists or playlist';

  @override
  String get noTracksFound => 'No Tracks Available';

  @override
  String get recent => 'Recent';
}
