enum SongErrorType { syncFailed, loadFailed, addSongsFailed, unknown }

enum PlaybackStatus { initial, loading, playing, paused, stopped, failure }

enum SongChangeType { upsert, delete }

enum PlaybackErrorType { fileDeleted, unknown }

/// How playback continues when a song ends.
enum RepeatMode {
  /// Stop after the last song of the queue.
  off,

  /// Start the queue again from the first song after the last one.
  all,

  /// Replay the current song.
  one,
}

/// When the sleep timer pauses playback.
enum SleepTimerOption {
  minutes5(Duration(minutes: 5)),
  minutes10(Duration(minutes: 10)),
  minutes15(Duration(minutes: 15)),
  minutes30(Duration(minutes: 30)),

  /// Pause when the current song ends.
  endOfTrack(null);

  const SleepTimerOption(this.duration);

  /// Time until playback pauses, or null for [endOfTrack].
  final Duration? duration;
}
