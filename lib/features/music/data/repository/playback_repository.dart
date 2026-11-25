abstract class PlaybackRepository {
  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
  bool get isPlaying;
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<void> get onSongComplete;

  /// Fires after any seek lands, whoever asked for it (UI or MPRIS).
  /// Drives the MPRIS `Seeked` signal.
  Stream<void> get onSeekComplete;
  Future<Duration?> getDuration();
  Future<Duration?> getCurrentPosition();
}
