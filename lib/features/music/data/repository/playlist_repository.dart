import 'package:mechanix_music/features/music/data/models/playlist_model.dart';

/// User playlists, stored as `.m3u8` files, plus the fixed Favourites
/// playlist ([PlaylistModel.favouritesId]).
abstract class PlaylistRepository {
  /// Favourites first, then the user playlists, oldest first.
  Future<List<PlaylistModel>> getPlaylists();

  /// Fires when playlists changed outside this repository (e.g. a song was
  /// added to or removed from the favourites from a track menu).
  Stream<void> get onChanged;

  /// Creates an empty playlist. Returns the existing one if [name] is taken.
  Future<PlaylistModel> createPlaylist(String name);

  /// Ids of the playlists that contain the song at [songPath].
  Future<Set<String>> playlistIdsContaining(String songPath);

  /// Makes the song at [songPath] a member of exactly the playlists in
  /// [playlistIds]: it is appended to newly selected playlists and removed
  /// from deselected ones. Fixed playlists (Favourites) are left untouched;
  /// they are changed with their own toggle.
  Future<void> setSongPlaylists(String songPath, Set<String> playlistIds);

  /// Renames the playlist with [id]. The Favourites playlist keeps its name.
  Future<void> renamePlaylist(String id, String name);

  /// Replaces the songs of the playlist with [id] (in play order).
  Future<void> setPlaylistSongs(String id, List<String> songPaths);
}
