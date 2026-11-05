import 'package:equatable/equatable.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

class PlaybackState extends Equatable {
  static const _unset = Object();

  final PlaybackStatus status;
  final SongModel? song;
  final List<SongModel> playbackList;

  /// Index of [song] in [playbackList] (-1 when the song is not in the list).
  final int currentIndex;
  final PlaybackErrorType? errorType;
  final Duration songDuration;

  /// What happens when a song ends.
  final RepeatMode repeatMode;

  /// Whether songs play in [shuffledList] order instead of [playbackList]
  /// order.
  final bool isShuffled;

  /// The songs of [playbackList] in shuffled play order. Only used while
  /// [isShuffled] is true.
  final List<SongModel> shuffledList;

  /// Songs the user chose to "play next", played before continuing the
  /// play order.
  final List<SongModel> playNextQueue;

  /// While a song from [playNextQueue] plays, the path of the last song
  /// played from the play order (the place to continue from). Null
  /// otherwise.
  final String? anchorPath;

  /// Active sleep timer, if any.
  final SleepTimerOption? sleepTimer;

  /// Whether [playbackList] is the library and follows its changes (false
  /// while a playlist or a folder is playing).
  final bool followsLibrary;

  const PlaybackState({
    this.status = PlaybackStatus.initial,
    this.song,
    this.playbackList = const [],
    this.currentIndex = 0,
    this.errorType,
    this.songDuration = Duration.zero,
    this.repeatMode = RepeatMode.off,
    this.isShuffled = false,
    this.shuffledList = const [],
    this.playNextQueue = const [],
    this.anchorPath,
    this.sleepTimer,
    this.followsLibrary = true,
  });

  /// The order songs are played in: shuffled or library order.
  List<SongModel> get playOrder => isShuffled ? shuffledList : playbackList;

  /// Position of the current song in [playOrder]. Matches [currentIndex]
  /// when not shuffled; songs are matched by path when shuffled.
  int get orderIndex {
    if (!isShuffled) return currentIndex;
    final path = anchorPath ?? song?.path;
    if (path == null) return 0;
    return shuffledList.indexWhere((s) => s.path == path);
  }

  /// The song that plays after the current one: the first queued "play
  /// next" song, otherwise [nextInOrder].
  SongModel? get nextSong =>
      playNextQueue.isNotEmpty ? playNextQueue.first : nextInOrder;

  /// The next song of the play order, if any. Wraps to the first song when
  /// [repeatMode] is [RepeatMode.all].
  SongModel? get nextInOrder {
    final order = playOrder;
    if (order.isEmpty) return null;
    final index = orderIndex;
    if (index < order.length - 1) return order[index + 1];
    return repeatMode == RepeatMode.all ? order.first : null;
  }

  /// The song before the current one in [playOrder], if any.
  SongModel? get previousSong {
    final index = orderIndex;
    return index > 0 ? playOrder[index - 1] : null;
  }

  bool get hasNext => nextSong != null;
  bool get hasPrevious => previousSong != null;

  /// Songs that will play after the current one: the "play next" queue,
  /// then the rest of the play order. When nothing is playing yet, the whole
  /// order.
  List<SongModel> get upNext {
    final order = playOrder;
    if (song == null) return [...playNextQueue, ...order];
    final index = orderIndex;
    final rest = index < 0 || index >= order.length
        ? order
        : order.sublist(index + 1);
    return [...playNextQueue, ...rest];
  }

  PlaybackState copyWith({
    PlaybackStatus? status,
    SongModel? song,
    List<SongModel>? playbackList,
    int? currentIndex,
    PlaybackErrorType? errorType,
    Duration? songDuration,
    RepeatMode? repeatMode,
    bool? isShuffled,
    List<SongModel>? shuffledList,
    List<SongModel>? playNextQueue,
    Object? anchorPath = _unset,
    Object? sleepTimer = _unset,
    bool? followsLibrary,
  }) => PlaybackState(
    status: status ?? this.status,
    song: song ?? this.song,
    playbackList: playbackList ?? this.playbackList,
    currentIndex: currentIndex ?? this.currentIndex,
    errorType: errorType ?? this.errorType,
    songDuration: songDuration ?? this.songDuration,
    repeatMode: repeatMode ?? this.repeatMode,
    isShuffled: isShuffled ?? this.isShuffled,
    shuffledList: shuffledList ?? this.shuffledList,
    playNextQueue: playNextQueue ?? this.playNextQueue,
    anchorPath: anchorPath == _unset
        ? this.anchorPath
        : anchorPath as String?,
    sleepTimer: sleepTimer == _unset
        ? this.sleepTimer
        : sleepTimer as SleepTimerOption?,
    followsLibrary: followsLibrary ?? this.followsLibrary,
  );

  @override
  List<Object?> get props => [
    status,
    song,
    playbackList,
    currentIndex,
    errorType,
    songDuration,
    repeatMode,
    isShuffled,
    shuffledList,
    playNextQueue,
    anchorPath,
    sleepTimer,
    followsLibrary,
  ];
}
