import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/playlist_model.dart';

/// Immutable view of a playlist for the UI ([PlaylistModel] is mutable and
/// has no value equality).
class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    required this.songPaths,
    required this.createdAt,
    this.isFixed = false,
  });

  factory Playlist.fromModel(PlaylistModel model) => Playlist(
    id: model.id,
    name: model.name,
    songPaths: List.unmodifiable(model.songPaths),
    createdAt: model.createdAt,
    isFixed: model.isFixed,
  );

  /// See [PlaylistModel.id].
  final String id;
  final String name;
  final List<String> songPaths;
  final DateTime createdAt;

  /// See [PlaylistModel.isFixed] (the Favourites playlist).
  final bool isFixed;

  int get trackCount => songPaths.length;

  Playlist copyWith({String? name, List<String>? songPaths}) => Playlist(
    id: id,
    name: name ?? this.name,
    songPaths: songPaths ?? this.songPaths,
    createdAt: createdAt,
    isFixed: isFixed,
  );

  @override
  List<Object?> get props => [id, name, songPaths, createdAt, isFixed];
}
