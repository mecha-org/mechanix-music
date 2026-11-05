/// A user playlist, stored as an `.m3u8` file. Songs are referenced by file
/// path (in play order) so a playlist survives library re-scans.
class PlaylistModel {
  /// File name of the playlist without the `.m3u8` extension. It does not
  /// change when the playlist is renamed.
  final String id;

  String name;

  DateTime createdAt;

  List<String> songPaths;

  /// True for the built-in Favourites playlist: always listed first, and it
  /// cannot be renamed or deleted.
  final bool isFixed;

  /// Id of the Favourites playlist. `:` never appears in a playlist file
  /// name, so it cannot clash with a user playlist.
  static const favouritesId = ':favourites';

  PlaylistModel({
    required this.id,
    required this.name,
    DateTime? createdAt,
    List<String>? songPaths,
    this.isFixed = false,
  }) : createdAt = createdAt ?? DateTime.now().toUtc(),
       songPaths = songPaths ?? [];

  int get trackCount => songPaths.length;
}
