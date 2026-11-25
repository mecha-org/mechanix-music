import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';

/// Publishes the player on the session bus as an MPRIS media player.
///
/// The only part of the feature that knows about D-Bus. Everything the
/// app tells it goes through [publish] and [notifySeeked]; everything
/// clients ask for goes to the `MprisPlayerControl` / `MprisApplicationControl`
/// it was built with.
abstract interface class MprisServer {
  /// The bus name actually owned, e.g. `org.mpris.MediaPlayer2.mechanix_music`
  /// (or `….instance<pid>` if another instance owns the plain one).
  /// Null until [start] succeeds.
  String? get busName;

  bool get isRunning;

  /// Connect, register `/org/mpris/MediaPlayer2`, and own the bus name.
  /// Throws if no session bus is reachable or no name can be owned.
  Future<void> start();

  /// Replace the visible state. Emits `PropertiesChanged` for the
  /// properties that differ from the last publish only.
  void publish(MprisPlayerState state);

  /// Emit `Seeked`. Call when the position jumps, whoever caused it;
  /// never for normal playback progress.
  void notifySeeked(Duration position);

  /// Release the bus name and, if the server opened it, the connection.
  Future<void> dispose();
}
