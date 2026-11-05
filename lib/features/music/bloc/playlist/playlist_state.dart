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

  PlaylistState copyWith({bool? isLoading, List<Playlist>? playlists}) =>
      PlaylistState(
        isLoading: isLoading ?? this.isLoading,
        playlists: playlists ?? this.playlists,
      );

  @override
  List<Object?> get props => [isLoading, playlists];
}
