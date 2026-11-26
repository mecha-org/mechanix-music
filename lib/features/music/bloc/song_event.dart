import 'package:equatable/equatable.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

sealed class SongEvent extends Equatable {
  const SongEvent();

  @override
  List<Object?> get props => [];
}

final class SongInitialized extends SongEvent {
  const SongInitialized();
}

final class SongLoadMore extends SongEvent {
  const SongLoadMore();
}

final class SongUpsert extends SongEvent {
  final SongModel song;
  const SongUpsert(this.song);

  @override
  List<Object?> get props => [song];
}

final class SongDelete extends SongEvent {
  final SongModel song;
  const SongDelete(this.song);

  @override
  List<Object?> get props => [song];
}

final class SongAddByPaths extends SongEvent {
  final List<String> paths;
  const SongAddByPaths(this.paths);

  @override
  List<Object?> get props => [paths];
}

final class SongSyncCompleted extends SongEvent {
  const SongSyncCompleted();
}

/// Adds [song] to, or removes it from, the favourites.
final class SongToggleFavourite extends SongEvent {
  final SongModel song;
  const SongToggleFavourite(this.song);

  @override
  List<Object?> get props => [song];
}
