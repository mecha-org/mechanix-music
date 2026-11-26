import 'package:equatable/equatable.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

abstract class PlaybackEvent extends Equatable {
  const PlaybackEvent();

  @override
  List<Object?> get props => [];
}

class PlaybackPlay extends PlaybackEvent {
  final SongModel song;

  /// True when [song] comes from the "play next" queue: the position in the
  /// play order is kept, so playback continues after the song that was
  /// playing before the queued ones.
  final bool fromQueue;

  const PlaybackPlay(this.song, {this.fromQueue = false});

  @override
  List<Object?> get props => [song, fromQueue];
}

class PlaybackPause extends PlaybackEvent {
  const PlaybackPause();
}

class PlaybackResume extends PlaybackEvent {
  const PlaybackResume();
}

class PlaybackSeek extends PlaybackEvent {
  final Duration position;
  const PlaybackSeek(this.position);

  @override
  List<Object?> get props => [position];
}

/// Seeks [offset] from the current position, within the song.
class PlaybackSeekBy extends PlaybackEvent {
  final Duration offset;
  const PlaybackSeekBy(this.offset);

  @override
  List<Object?> get props => [offset];
}

class PlaybackStop extends PlaybackEvent {
  const PlaybackStop();
}

class PlaybackPlayNext extends PlaybackEvent {
  const PlaybackPlayNext();
}

class PlaybackPlayPrevious extends PlaybackEvent {
  const PlaybackPlayPrevious();
}

/// Sets the play queue.
///
/// [followsLibrary] is true when [playbackList] is the library (All tracks):
/// the queue then keeps following library changes. A playlist or a folder
/// passes false, so library updates no longer replace it.
class PlaybackListUpdated extends PlaybackEvent {
  final List<SongModel> playbackList;
  final bool followsLibrary;
  const PlaybackListUpdated(this.playbackList, {this.followsLibrary = true});

  @override
  List<Object?> get props => [playbackList, followsLibrary];
}

/// The library list changed (from SongBloc). Only applied while the queue
/// follows the library.
class PlaybackLibraryUpdated extends PlaybackEvent {
  final List<SongModel> songs;
  const PlaybackLibraryUpdated(this.songs);

  @override
  List<Object?> get props => [songs];
}

class PlaybackDurationUpdated extends PlaybackEvent {
  final Duration duration;
  const PlaybackDurationUpdated(this.duration);

  @override
  List<Object?> get props => [duration];
}

/// Turns shuffle on or off. When turned on, the current song stays first and
/// the rest of the queue is played in random order.
class PlaybackToggleShuffle extends PlaybackEvent {
  const PlaybackToggleShuffle();
}

/// Cycles the repeat mode: off → all → one → off.
class PlaybackCycleRepeatMode extends PlaybackEvent {
  const PlaybackCycleRepeatMode();
}

/// Plays [song] right after the current one (before the rest of the queue).
/// Plays it immediately when nothing is playing.
class PlaybackQueueNext extends PlaybackEvent {
  final SongModel song;
  const PlaybackQueueNext(this.song);

  @override
  List<Object?> get props => [song];
}

/// Adds a song to the end of the "play next" queue: after the songs queued
/// before it, before the rest of the play order.
class PlaybackQueueAdd extends PlaybackEvent {
  final SongModel song;
  const PlaybackQueueAdd(this.song);

  @override
  List<Object?> get props => [song];
}

/// Moves a song of [PlaybackState.upNext] from [from] to [to] (its final
/// position, as [ReorderableList.onReorderItem] reports it).
class PlaybackQueueMoved extends PlaybackEvent {
  final int from;
  final int to;
  const PlaybackQueueMoved(this.from, this.to);

  @override
  List<Object?> get props => [from, to];
}

/// Removes the song at [index] of [PlaybackState.upNext].
class PlaybackQueueRemoved extends PlaybackEvent {
  final int index;
  const PlaybackQueueRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

/// Sets (or with null, cancels) the sleep timer.
class PlaybackSetSleepTimer extends PlaybackEvent {
  final SleepTimerOption? option;
  const PlaybackSetSleepTimer(this.option);

  @override
  List<Object?> get props => [option];
}

/// The timed sleep timer ran out.
class PlaybackSleepTimerElapsed extends PlaybackEvent {
  const PlaybackSleepTimerElapsed();
}
