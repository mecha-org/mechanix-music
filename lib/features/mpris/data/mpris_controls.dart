/// What MPRIS clients may ask the player to do
/// (`org.mpris.MediaPlayer2.Player` methods).
///
/// Implemented by `PlaybackMprisBridge`, which turns each call into a
/// `PlaybackEvent` on the `PlaybackBloc`. Implementations must not publish
/// state themselves: the result arrives through the bloc's state stream,
/// like every other change.
abstract interface class MprisPlayerControl {
  Future<void> play();
  Future<void> pause();
  Future<void> playPause();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();

  /// Absolute position. Relative `Seek` and `SetPosition` are resolved
  /// to this by the server.
  Future<void> seekTo(Duration position);

  /// Current position, read synchronously whenever a client asks for
  /// the `Position` property. Must be cheap: return a cached value.
  Duration get position;
}

/// What MPRIS clients may ask the application to do
/// (`org.mpris.MediaPlayer2` methods).
abstract interface class MprisApplicationControl {
  /// Whether `raise()` does anything (`CanRaise`).
  bool get canRaise;

  /// Whether `quit()` does anything (`CanQuit`).
  bool get canQuit;

  /// Bring the music window to the front (via the Mechanix compositor).
  Future<void> raise();

  /// Close the app.
  Future<void> quit();
}
