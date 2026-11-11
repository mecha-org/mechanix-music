import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';

sealed class PlaylistEvent extends Equatable {
  const PlaylistEvent();

  @override
  List<Object?> get props => [];
}

/// (Re)loads all playlists, e.g. after the "Add to playlist" sheet saved.
final class PlaylistsRequested extends PlaylistEvent {
  const PlaylistsRequested();
}

/// Creates an empty playlist named "Playlist N". [created] completes with
/// the new playlist so the UI can open it.
final class PlaylistCreateRequested extends PlaylistEvent {
  const PlaylistCreateRequested({this.created});

  final Completer<Playlist>? created;
}

final class PlaylistRenamed extends PlaylistEvent {
  const PlaylistRenamed(this.playlistId, this.name);

  final String playlistId;
  final String name;

  @override
  List<Object?> get props => [playlistId, name];
}

/// Appends a song to the end of a playlist.
final class PlaylistSongAdded extends PlaylistEvent {
  const PlaylistSongAdded(this.playlistId, this.songPath);

  final String playlistId;
  final String songPath;

  @override
  List<Object?> get props => [playlistId, songPath];
}

final class PlaylistSongRemoved extends PlaylistEvent {
  const PlaylistSongRemoved(this.playlistId, this.songPath);

  final String playlistId;
  final String songPath;

  @override
  List<Object?> get props => [playlistId, songPath];
}

/// Moves a song inside a playlist. Indices follow [ReorderableList]'s
/// `onReorder` convention ([newIndex] counts the moved item's old slot).
final class PlaylistSongMoved extends PlaylistEvent {
  const PlaylistSongMoved(this.playlistId, this.oldIndex, this.newIndex);

  final String playlistId;
  final int oldIndex;
  final int newIndex;

  @override
  List<Object?> get props => [playlistId, oldIndex, newIndex];
}
