class Constants {
  /// Tantivy music index holding the song library (relative to `$HOME`).
  static const String tantivyIndexPath =
      '.config/mechanix_apps/music/music_index';

  /// Folder of the user's `.m3u8` playlists (relative to `$HOME`).
  static const String playlistsDirPath =
      '.config/mechanix_apps/music/playlists';

  /// The favourites `.m3u8` playlist (relative to `$HOME`), next to the
  /// user's playlists in [playlistsDirPath]. It is shown as the fixed
  /// Favourites playlist, not as a user playlist.
  static const String favouritesFilePath =
      '.config/mechanix_apps/music/playlists/favourites.m3u8';

  /// Where the favourites were kept before; moved to [favouritesFilePath]
  /// on first use.
  static const String legacyFavouritesFilePath =
      '.config/mechanix_apps/music/favourites.m3u8';
  static const String favouritesPlaylistName = 'Favourites';

  /// Songs opened from search, newest first, as an `.m3u8` playlist
  /// (relative to `$HOME`).
  static const String recentSearchesFilePath =
      '.config/mechanix_apps/music/recent_searches.m3u8';

  /// Maximum number of songs kept in the recent searches.
  static const int recentSearchesLimit = 10;

  static const String musicDirPath = '/Music';
  static const Duration debounceDuration = Duration(milliseconds: 300);
  static const audioExt = [
    '.mp3',
    '.wav',
    '.flac',
    '.m4a',
    '.aac',
    '.ogg',
    '.opus',
  ];
  static const int pageSize = 20;
  static const loadMoreSongsThreshold =
      5; // to fetch next songs on list when 5 are remain.

  /// Maximum number of songs returned by a library search.
  static const int searchResultLimit = 50;

  /// Delay after the last keystroke before the library is searched.
  static const Duration searchDebounce = Duration(milliseconds: 250);

  static const double artworkSize = 280.0;
}
