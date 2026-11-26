import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';

class PlaylistState extends Equatable {
  const PlaylistState({this.isLoading = true, this.playlists = const []});

  final bool isLoading;

  /// All playlists, oldest first.
  final List<Playlist> playlists;

  Playlist? byId(String id) {
    for (final playlist in playlists) {
      if (playlist.id == id) return playlist;
    }
    return null;
  }

  /// Whether another playlist than [exceptId] is called [name] (trimmed,
  /// ignoring case). Includes Favourites.
  bool isNameTaken(String name, {String? exceptId}) {
    final wanted = name.trim().toLowerCase();
    return playlists.any(
      (p) => p.id != exceptId && p.name.trim().toLowerCase() == wanted,
    );
  }

  PlaylistState copyWith({bool? isLoading, List<Playlist>? playlists}) =>
      PlaylistState(
        isLoading: isLoading ?? this.isLoading,
        playlists: playlists ?? this.playlists,
      );

  @override
  List<Object?> get props => [isLoading, playlists];
}
