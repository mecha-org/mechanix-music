import 'package:mechanix_music/core/utils/enums.dart';

/// A song in the library.
///
/// Songs are stored in the Tantivy music index (see `TantivySongIndex`).
/// [isFavourite] is not stored with the song: it comes from the favourites
/// `.m3u8` playlist. [isExternal] is derived from the path (outside the
/// music folder). [toJson]/[SongModel.fromJson] is used to pass songs
/// between isolates.
class SongModel {
  /// Stable id of the song.
  String id;

  /// Absolute path of the audio file. Unique in the library.
  String path;

  String title;
  String artist;
  String? album;
  String? duration;
  /// Cover art as base64-encoded image bytes (shown with
  /// `ArtworkCache.image`), stored in the index as `artwork_base64`.
  String? artworkBase64;

  /// UTC timestamp of when this song was last scanned from disk.
  DateTime lastScannedAt;

  /// Modification time of the file when it was scanned (ms since epoch).
  int mtime;

  /// Size of the file in bytes when it was scanned.
  int size;

  /// When the song entered the library (UTC).
  DateTime? addedAt;

  bool isExternal; // If true, this song was imported from an external directory

  /// Whether the user added this song to their favourites.
  bool isFavourite;

  SongModel({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.artworkBase64,
    DateTime? lastScannedAt,
    this.mtime = 0,
    this.size = 0,
    this.addedAt,
    this.isExternal = false,
    this.isFavourite = false,
  }) : lastScannedAt = lastScannedAt ?? DateTime.now().toUtc();

  /// Duration in whole seconds, parsed from [duration] ("mm:ss" or
  /// "h:mm:ss"), or null when unknown.
  int? get durationInSeconds {
    final value = duration;
    if (value == null || value.isEmpty) return null;
    var seconds = 0;
    for (final part in value.split(':')) {
      final n = int.tryParse(part);
      if (n == null) return null;
      seconds = seconds * 60 + n;
    }
    return seconds;
  }

  /// Formats [seconds] like [duration] ("mm:ss").
  static String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'duration': duration,
    'artworkBase64': artworkBase64,
    'lastScannedAt': lastScannedAt.toUtc().toIso8601String(),
    'mtime': mtime,
    'size': size,
    'addedAt': addedAt?.toUtc().toIso8601String(),
    'isExternal': isExternal,
  };

  factory SongModel.fromJson(Map<String, Object?> json) => SongModel(
    id: json['id'] as String,
    path: json['path'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String?,
    duration: json['duration'] as String?,
    artworkBase64: json['artworkBase64'] as String?,
    lastScannedAt: DateTime.tryParse(
      json['lastScannedAt'] as String? ?? '',
    )?.toUtc(),
    mtime: json['mtime'] as int? ?? 0,
    size: json['size'] as int? ?? 0,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '')?.toUtc(),
    isExternal: json['isExternal'] as bool? ?? false,
  );
}

/// Orders songs like the index does for [sort].
int compareSongs(SongSort sort, SongModel a, SongModel b) {
  String key(String value) => value.trim().toLowerCase();
  int byTitle() => key(a.title).compareTo(key(b.title));
  int byArtist() => key(a.artist).compareTo(key(b.artist));
  int directed(int order) => sort.descending ? -order : order;

  final first = switch (sort) {
    SongSort.title => directed(byTitle()),
    SongSort.artist => directed(byArtist()),
    SongSort.dateAdded => _nullsLast(a.addedAt, b.addedAt, directed),
    SongSort.duration => _nullsLast(
      a.durationInSeconds,
      b.durationInSeconds,
      directed,
    ),
  };
  if (first != 0) return first;
  final second = switch (sort) {
    SongSort.title => byArtist(),
    SongSort.artist => byTitle(),
    SongSort.dateAdded || SongSort.duration => 0,
  };
  return second != 0 ? second : a.path.compareTo(b.path);
}

int _nullsLast<T extends Comparable<Object>>(
  T? a,
  T? b,
  int Function(int order) directed,
) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
  return directed(a.compareTo(b));
}
