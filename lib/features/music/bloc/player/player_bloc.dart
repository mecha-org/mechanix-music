import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/exceptions/app_exceptions.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/bloc/song_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

class PlaybackBloc extends Bloc<PlaybackEvent, PlaybackState> {
  final PlaybackRepository _repo;
  Timer? _playDebounce; // Handle rapid song clicks efficiently
  final SongBloc _songBloc;
  late final StreamSubscription<SongState> _songSub;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<Duration> _durationSub;

  /// Source of randomness for shuffle (injectable for tests).
  final Random _random;

  Timer? _sleepTimer;

  PlaybackBloc(this._repo, this._songBloc, {Random? random})
    : _random = random ?? Random(),
      super(
        PlaybackState(
          playbackList: _songBloc.state is SongLoaded
              ? (_songBloc.state as SongLoaded).songs
              : [],
        ),
      ) {
    on<PlaybackPlay>(_onPlay);
    on<PlaybackPause>(_onPause);
    on<PlaybackResume>(_onResume);
    on<PlaybackSeek>(_onSeek);
    // Sequential, so quick repeats add up.
    on<PlaybackSeekBy>(
      _onSeekBy,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    on<PlaybackStop>(_onStop);
    on<PlaybackPlayNext>(_onPlayNext);
    on<PlaybackPlayPrevious>(_onPlayPrevious);
    on<PlaybackListUpdated>(_onPlaybackListUpdated);
    on<PlaybackLibraryUpdated>(_onLibraryUpdated);
    on<PlaybackDurationUpdated>(_onDurationUpdated);
    on<PlaybackToggleShuffle>(_onToggleShuffle);
    on<PlaybackCycleRepeatMode>(_onCycleRepeatMode);
    on<PlaybackQueueNext>(_onQueueNext);
    on<PlaybackQueueAdd>(_onQueueAdd);
    on<PlaybackQueueMoved>(_onQueueMoved);
    on<PlaybackQueueRemoved>(_onQueueRemoved);
    on<PlaybackSetSleepTimer>(_onSetSleepTimer);
    on<PlaybackSleepTimerElapsed>(_onSleepTimerElapsed);

    _listenToSongBloc();
    _listenToSongComplete();
    _listenToDurationChanged();
  }

  void _listenToDurationChanged() {
    _durationSub = _repo.onDurationChanged.listen((duration) async {
      if (duration.inMilliseconds > 0) {
        AppLogger.i('[PlaybackBloc] Duration ready: $duration');
        add(PlaybackDurationUpdated(duration));
        return;
      }
    });
  }

  void _onDurationUpdated(
    PlaybackDurationUpdated event,
    Emitter<PlaybackState> emit,
  ) {
    emit(state.copyWith(songDuration: event.duration));
  }

  void _listenToSongBloc() {
    _songSub = _songBloc.stream.listen((songState) {
      // Not the state itself: it would print every song of the library.
      AppLogger.i(
        '[PlaybackBloc] Song state updated: ${switch (songState) {
          SongLoaded(:final songs) => 'loaded (${songs.length} songs)',
          _ => songState.runtimeType,
        }}',
      );
      if (songState is SongLoaded) {
        add(PlaybackLibraryUpdated(songState.songs));
      }
    });
  }

  void _listenToSongComplete() {
    _completeSub = _repo.onSongComplete.listen((_) {
      AppLogger.i('[PlaybackBloc] Song completed, attempting to play next...');
      final current = state.song;
      if (state.sleepTimer == SleepTimerOption.endOfTrack) {
        // Sleep timer "end of track": stop here.
        add(const PlaybackSetSleepTimer(null));
        add(const PlaybackPause());
      } else if (state.repeatMode == RepeatMode.one && current != null) {
        add(PlaybackPlay(current));
      } else if (state.hasNext) {
        add(const PlaybackPlayNext());
      } else {
        AppLogger.i('[PlaybackBloc] No next song available — pausing playback');
        add(const PlaybackPause());
      }
    });
  }

  void _onLibraryUpdated(
    PlaybackLibraryUpdated event,
    Emitter<PlaybackState> emit,
  ) {
    // A playlist or folder queue is not replaced by library changes.
    if (!state.followsLibrary) return;
    // Songs moved into the queue stay out (the current song stays findable).
    final moved = {...state.movedToQueue}..remove(state.song?.path);
    _applyList(
      moved.isEmpty
          ? event.songs
          : [
              for (final s in event.songs)
                if (!moved.contains(s.path)) s,
            ],
      followsLibrary: true,
      stopIfMissing: true,
      emit: emit,
    );
  }

  void _onPlaybackListUpdated(
    PlaybackListUpdated event,
    Emitter<PlaybackState> emit,
  ) => _applyList(
    event.playbackList,
    followsLibrary: event.followsLibrary,
    stopIfMissing: false,
    // A new list: songs moved into the queue from the old one count again.
    movedToQueue: const {},
    emit: emit,
  );

  /// Replaces the play queue with [updatedList]. [movedToQueue] replaces
  /// [PlaybackState.movedToQueue] when given.
  void _applyList(
    List<SongModel> updatedList, {
    required bool followsLibrary,
    required bool stopIfMissing,
    Set<String>? movedToQueue,
    required Emitter<PlaybackState> emit,
  }) {
    final shuffledList = state.isShuffled
        ? _mergeShuffledList(state.shuffledList, updatedList, state.song)
        : null;

    // No song playing yet — just sync the list
    if (state.song == null) {
      emit(
        state.copyWith(
          playbackList: updatedList,
          shuffledList: shuffledList,
          followsLibrary: followsLibrary,
          movedToQueue: movedToQueue,
        ),
      );
      return;
    }

    // Find current song in the updated list. Matched by path: a metadata
    // update replaces the SongModel instance of the same file.
    final currentPath = state.song!.path;
    final newIndex = updatedList.indexWhere((s) => s.path == currentPath);

    if (newIndex == -1 && !stopIfMissing) {
      emit(
        state.copyWith(
          playbackList: updatedList,
          currentIndex: -1,
          anchorPath: null,
          shuffledList: shuffledList,
          followsLibrary: followsLibrary,
          movedToQueue: movedToQueue,
        ),
      );
      return;
    }

    if (newIndex == -1) {
      // Current song was deleted — stop playback (keep the user's modes).
      _repo.stop();
      emit(
        PlaybackState(
          status: PlaybackStatus.stopped,
          repeatMode: state.repeatMode,
          isShuffled: state.isShuffled,
          sleepTimer: state.sleepTimer,
        ),
      );
      return;
    }

    // Song still exists — update list and correct the index
    emit(
      state.copyWith(
        song: updatedList[newIndex],
        playbackList: updatedList,
        currentIndex: newIndex,
        shuffledList: shuffledList,
        followsLibrary: followsLibrary,
        movedToQueue: movedToQueue,
      ),
    );
  }

  Future<void> _onPlay(PlaybackPlay event, Emitter<PlaybackState> emit) async {
    // A queued "play next" song keeps the place in the play order, so the
    // order continues after the song that was playing before it.
    final fromQueue = event.fromQueue;
    final index = fromQueue
        ? state.currentIndex
        : state.playbackList.indexWhere((s) => s.path == event.song.path);
    final anchorPath = fromQueue ? state.anchorPath ?? state.song?.path : null;

    // A song played directly is no longer waiting in the "play next" queue.
    final playNextQueue = fromQueue
        ? null
        : state.playNextQueue.where((s) => s.path != event.song.path).toList();

    // When shuffled, keep the shuffled order if the song is part of it (e.g.
    // next/previous or a tap on an upcoming song); otherwise start a new
    // shuffled order beginning with this song.
    List<SongModel>? shuffledList;
    if (!fromQueue &&
        state.isShuffled &&
        !state.shuffledList.any((s) => s.path == event.song.path)) {
      shuffledList = _shuffle(state.playbackList, first: event.song);
    }

    // Cancel pending debounce
    _playDebounce?.cancel();

    // Stop old song immediately — no more audio, no stale duration
    if (_repo.isPlaying) await _repo.stop();

    // UI updates immediately
    emit(
      state.copyWith(
        status: PlaybackStatus.loading,
        song: event.song,
        currentIndex: index,
        songDuration: Duration.zero, // reset stale duration
        shuffledList: shuffledList,
        anchorPath: anchorPath,
        playNextQueue: playNextQueue,
      ),
    );

    final completer =
        Completer<void>(); // hold the emit state to update on debounce complete

    _playDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        await _repo.play(event.song.path);
        completer.complete();
      } on PlaybackFileNotFoundException catch (e) {
        AppLogger.e('Error during playback (file not found): $e');
        emit(
          state.copyWith(
            status: PlaybackStatus.failure,
            errorType: PlaybackErrorType.fileDeleted,
          ),
        );

        if (state.hasNext) {
          add(const PlaybackPlayNext());
        }
        unawaited(_songBloc.songRepository.deleteSongByPath(event.song.path));

        completer.completeError(e);
      } catch (e) {
        AppLogger.e('Error during playback: $e');
        emit(
          state.copyWith(
            status: PlaybackStatus.failure,
            errorType: PlaybackErrorType.unknown,
          ),
        );
        completer.completeError(e);
      }
    });

    try {
      await completer.future;
      emit(state.copyWith(status: PlaybackStatus.playing));
    } catch (e) {
      // Debounce timer catch block already emitted the failure state.
      AppLogger.e('Error during playback: $e');
    }
  }

  Future<void> _onPlayNext(
    PlaybackPlayNext event,
    Emitter<PlaybackState> emit,
  ) async {
    // Songs the user queued with "play next" come first.
    if (state.playNextQueue.isNotEmpty) {
      final queued = state.playNextQueue.first;
      emit(state.copyWith(playNextQueue: state.playNextQueue.sublist(1)));
      add(PlaybackPlay(queued, fromQueue: true));
      return;
    }

    final nextSong = state.nextInOrder;
    if (nextSong == null) return;

    final order = state.playOrder;
    final nextIndex = order.indexWhere((s) => s.path == nextSong.path);

    // Remaining songs after this next play
    final remaining = order.length - 1 - nextIndex;
    if (remaining <= Constants.loadMoreSongsThreshold) {
      _songBloc.add(const SongLoadMore());
    }

    add(PlaybackPlay(nextSong));
  }

  Future<void> _onPlayPrevious(
    PlaybackPlayPrevious event,
    Emitter<PlaybackState> emit,
  ) async {
    final prevSong = state.previousSong;
    if (prevSong == null) return;

    add(PlaybackPlay(prevSong));
  }

  void _onToggleShuffle(
    PlaybackToggleShuffle event,
    Emitter<PlaybackState> emit,
  ) {
    if (state.isShuffled) {
      emit(state.copyWith(isShuffled: false, shuffledList: const []));
    } else {
      emit(
        state.copyWith(
          isShuffled: true,
          shuffledList: _shuffle(state.playbackList, first: state.song),
        ),
      );
    }
  }

  void _onQueueAdd(PlaybackQueueAdd event, Emitter<PlaybackState> emit) {
    if (state.song == null) {
      add(PlaybackPlay(event.song));
      return;
    }
    final path = event.song.path;
    // Already queued: the menu says so; the queue stays as it is.
    if (state.playNextQueue.any((s) => s.path == path)) return;
    emit(
      _withoutUpcoming(path).copyWith(
        playNextQueue: [...state.playNextQueue, event.song],
      ),
    );
  }

  /// The state with the song at [path] taken out of the rest of the play
  /// order (not out of the songs already played), as it is being queued:
  /// it then plays once, from the queue.
  PlaybackState _withoutUpcoming(String path) {
    final order = state.playOrder;
    final at = order.indexWhere((s) => s.path == path, state.orderIndex + 1);
    if (at == -1) return state;
    final newOrder = [...order]..removeAt(at);
    final moved = {...state.movedToQueue, path};
    if (!state.isShuffled) {
      return state.copyWith(playbackList: newOrder, movedToQueue: moved);
    }
    // Also out of the plain list, so turning shuffle off doesn't bring it
    // back; its index is looked up again.
    final playbackList = [
      for (final s in state.playbackList)
        if (s.path != path) s,
    ];
    final current = state.anchorPath ?? state.song?.path;
    return state.copyWith(
      shuffledList: newOrder,
      playbackList: playbackList,
      currentIndex: playbackList.indexWhere((s) => s.path == current),
      movedToQueue: moved,
    );
  }

  void _onQueueMoved(PlaybackQueueMoved event, Emitter<PlaybackState> emit) {
    final upNext = state.upNext;
    final from = event.from;
    if (from < 0 || from >= upNext.length) return;
    final to = event.to.clamp(0, upNext.length - 1);
    if (to == from) return;

    // Within the "play next" songs: only their order changes.
    final queued = state.playNextQueue.length;
    if (from < queued && to < queued) {
      final queue = [...state.playNextQueue];
      queue.insert(to, queue.removeAt(from));
      emit(state.copyWith(playNextQueue: queue));
      return;
    }
    final moved = [...upNext];
    moved.insert(to, moved.removeAt(from));
    _setUpNext(moved, emit);
  }

  void _onQueueRemoved(
    PlaybackQueueRemoved event,
    Emitter<PlaybackState> emit,
  ) {
    final upNext = state.upNext;
    final index = event.index;
    if (index < 0 || index >= upNext.length) return;

    if (index < state.playNextQueue.length) {
      emit(
        state.copyWith(
          playNextQueue: [...state.playNextQueue]..removeAt(index),
        ),
      );
      return;
    }
    _setUpNext([...upNext]..removeAt(index), emit);
  }

  /// Makes [upNext] what plays after the current song. The "play next"
  /// songs become part of the play order, and the edited order no longer
  /// follows the library (a library change would undo the edit).
  void _setUpNext(List<SongModel> upNext, Emitter<PlaybackState> emit) {
    final song = state.song;
    final order = state.playOrder;
    final index = song == null ? -1 : state.orderIndex;
    final played = index >= 0 && index < order.length
        ? order.sublist(0, index + 1)
        : const <SongModel>[];

    // Each song once: the current song (or the song a "play next" song
    // follows) stays where it is; a song moved up is no longer "played".
    final seen = <String>{?song?.path, ?state.anchorPath};
    final upcoming = [
      for (final s in upNext)
        if (seen.add(s.path)) s,
    ];
    final upcomingPaths = {for (final s in upcoming) s.path};
    final newOrder = [
      for (final s in played)
        if (!upcomingPaths.contains(s.path)) s,
      ...upcoming,
    ];

    // Shuffled: the order is the shuffled list; the plain list keeps its
    // order but loses removed songs and gains queued ones.
    final List<SongModel> playbackList;
    if (state.isShuffled) {
      final inOrder = {for (final s in newOrder) s.path};
      final known = {for (final s in state.playbackList) s.path};
      playbackList = [
        for (final s in state.playbackList)
          if (inOrder.contains(s.path)) s,
        for (final s in newOrder)
          if (!known.contains(s.path)) s,
      ];
    } else {
      playbackList = newOrder;
    }

    final anchor = state.anchorPath ?? song?.path;
    emit(
      state.copyWith(
        playbackList: playbackList,
        shuffledList: state.isShuffled ? newOrder : null,
        playNextQueue: const [],
        currentIndex: song == null
            ? null
            : playbackList.indexWhere((s) => s.path == anchor),
        followsLibrary: false,
      ),
    );
  }

  void _onQueueNext(PlaybackQueueNext event, Emitter<PlaybackState> emit) {
    if (state.song == null) {
      add(PlaybackPlay(event.song));
      return;
    }
    final path = event.song.path;
    emit(
      _withoutUpcoming(path).copyWith(
        playNextQueue: [
          event.song,
          ...state.playNextQueue.where((s) => s.path != path),
        ],
      ),
    );
  }

  void _onSetSleepTimer(
    PlaybackSetSleepTimer event,
    Emitter<PlaybackState> emit,
  ) {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    final duration = event.option?.duration;
    if (duration != null) {
      _sleepTimer = Timer(duration, () {
        if (!isClosed) add(const PlaybackSleepTimerElapsed());
      });
    }
    emit(state.copyWith(sleepTimer: event.option));
  }

  void _onSleepTimerElapsed(
    PlaybackSleepTimerElapsed event,
    Emitter<PlaybackState> emit,
  ) {
    _sleepTimer = null;
    emit(state.copyWith(sleepTimer: null));
    add(const PlaybackPause());
  }

  void _onCycleRepeatMode(
    PlaybackCycleRepeatMode event,
    Emitter<PlaybackState> emit,
  ) {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    emit(state.copyWith(repeatMode: next));
  }

  /// Returns [songs] in random order. When [first] is in [songs] it is moved
  /// to the front, so the current song stays current.
  List<SongModel> _shuffle(List<SongModel> songs, {SongModel? first}) {
    final rest = [...songs];
    SongModel? head;
    if (first != null) {
      final index = rest.indexWhere((s) => s.path == first.path);
      if (index != -1) head = rest.removeAt(index);
    }
    rest.shuffle(_random);
    return [?head, ...rest];
  }

  /// Keeps the existing shuffled order for songs that are still in
  /// [updated] (using their updated instances), drops removed songs and adds
  /// newly loaded songs at the end in random order.
  List<SongModel> _mergeShuffledList(
    List<SongModel> shuffled,
    List<SongModel> updated,
    SongModel? current,
  ) {
    if (shuffled.isEmpty) return _shuffle(updated, first: current);

    final updatedByPath = {for (final s in updated) s.path: s};
    final kept = <SongModel>[];
    final keptPaths = <String>{};
    for (final s in shuffled) {
      final match = updatedByPath[s.path];
      if (match != null && keptPaths.add(s.path)) kept.add(match);
    }
    final added = updated.where((s) => !keptPaths.contains(s.path)).toList()
      ..shuffle(_random);
    return [...kept, ...added];
  }

  Future<void> _onPause(
    PlaybackPause event,
    Emitter<PlaybackState> emit,
  ) async {
    if (state.song == null) return;
    if (state.status != PlaybackStatus.playing && !_repo.isPlaying) {
      return;
    }
    try {
      await _repo.pause();
      emit(
        state.copyWith(
          status: _repo.isPlaying
              ? PlaybackStatus.playing
              : PlaybackStatus.paused,
        ),
      );
    } catch (e) {
      AppLogger.e('Error during pause: $e');

      emit(
        state.copyWith(
          status: PlaybackStatus.failure,
          errorType: PlaybackErrorType.unknown,
        ),
      );
    }
  }

  Future<void> _onResume(
    PlaybackResume event,
    Emitter<PlaybackState> emit,
  ) async {
    if (state.song == null) return;
    if (state.status == PlaybackStatus.playing || _repo.isPlaying) {
      return;
    }

    try {
      await _repo.resume();
      emit(
        state.copyWith(
          status: _repo.isPlaying
              ? PlaybackStatus.playing
              : PlaybackStatus.paused,
        ),
      );
    } catch (e) {
      AppLogger.e('Error during resume: $e');

      emit(
        state.copyWith(
          status: PlaybackStatus.failure,
          errorType: PlaybackErrorType.unknown,
        ),
      );
    }
  }

  Future<void> _onSeek(PlaybackSeek event, Emitter<PlaybackState> emit) async {
    if (state.song == null) return;
    await _seekTo(event.position, emit);
  }

  Future<void> _onSeekBy(
    PlaybackSeekBy event,
    Emitter<PlaybackState> emit,
  ) async {
    final length = state.songDuration;
    if (state.song == null || length <= Duration.zero) return;

    final Duration current;
    try {
      current = await _repo.getCurrentPosition() ?? Duration.zero;
    } catch (e) {
      AppLogger.e('Error reading the position: $e');
      return;
    }
    var target = current + event.offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > length) target = length;
    await _seekTo(target, emit);
  }

  Future<void> _seekTo(Duration position, Emitter<PlaybackState> emit) async {
    try {
      await _repo.seek(position);
    } catch (e) {
      AppLogger.e('Error during seek: $e');

      emit(
        state.copyWith(
          status: PlaybackStatus.failure,
          errorType: PlaybackErrorType.unknown,
        ),
      );
    }
  }

  Future<void> _onStop(PlaybackStop event, Emitter<PlaybackState> emit) async {
    try {
      await _repo.stop();
      emit(
        PlaybackState(
          status: PlaybackStatus.stopped,
          repeatMode: state.repeatMode,
          isShuffled: state.isShuffled,
          sleepTimer: state.sleepTimer,
        ),
      );
    } catch (e) {
      AppLogger.e('Error during stop: $e');

      emit(
        state.copyWith(
          status: PlaybackStatus.failure,
          errorType: PlaybackErrorType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    _playDebounce?.cancel();
    _sleepTimer?.cancel();
    await _songSub.cancel();
    await _completeSub.cancel();
    await _durationSub.cancel();
    await _repo.dispose();
    return super.close();
  }
}
