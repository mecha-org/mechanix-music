import 'package:equatable/equatable.dart';

/// An album (artist + album name) and its number of songs.
class AlbumSummary extends Equatable {
  const AlbumSummary({
    required this.artist,
    required this.album,
    required this.songCount,
  });

  final String artist;
  final String album;
  final int songCount;

  @override
  List<Object?> get props => [artist, album, songCount];
}
