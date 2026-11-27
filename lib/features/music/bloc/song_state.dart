import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

sealed class SongState extends Equatable {
  const SongState();

  @override
  List<Object?> get props => [];
}

final class SongInitial extends SongState {
  const SongInitial();
}

final class SongLoading extends SongState {
  const SongLoading();
}

final class SongLoaded extends SongState {
  final List<SongModel> songs;
  final bool hasMore;
  final bool isLoadingMore;
  final SongSort sort;

  /// Songs in the library.
  final int totalCount;

  const SongLoaded({
    required this.songs,
    required this.hasMore,
    this.isLoadingMore = false,
    this.sort = SongSort.title,
    this.totalCount = 0,
  });

  /// Library songs not loaded yet.
  int get unloadedCount => math.max(0, totalCount - songs.length);

  SongLoaded copyWith({
    List<SongModel>? songs,
    bool? hasMore,
    bool? isLoadingMore,
    int? totalCount,
  }) => SongLoaded(
    songs: songs ?? this.songs,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    sort: sort,
    totalCount: totalCount ?? this.totalCount,
  );

  @override
  List<Object?> get props => [
    songs,
    hasMore,
    isLoadingMore,
    sort,
    totalCount,
  ];
}

final class SongError extends SongState {
  final SongErrorType errorType;

  const SongError(this.errorType);

  @override
  List<Object?> get props => [errorType];
}
