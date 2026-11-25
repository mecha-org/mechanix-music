import 'package:equatable/equatable.dart';

/// MPRIS `PlaybackStatus`. MPRIS has exactly three states, so the app's
/// richer `PlaybackStatus` is folded into these by `PlaybackStateMapper`.
enum MprisPlaybackStatus { playing, paused, stopped }

/// The metadata of the current track, in app terms (not D-Bus types).
/// The D-Bus server turns it into the `Metadata` a{sv} dictionary.
class MprisTrack extends Equatable {
  /// Stable id of the track. Becomes `mpris:trackid` (encoded as an
  /// object path by the server). Source: `SongModel.id`.
  final String id;

  /// `xesam:title`. Source: `SongModel.title`.
  final String title;

  /// `xesam:artist` (always a list on the bus). Source: `[SongModel.artist]`.
  final List<String> artists;

  /// `xesam:album`. Source: `SongModel.album`.
  final String? album;

  /// `mpris:length`. Null while the engine hasn't reported a duration yet.
  /// Source: `PlaybackState.songDuration` (when > zero).
  final Duration? length;

  /// `mpris:artUrl`, a `file://` URI. Source: `SongModel.artworkBase64`,
  /// written to a file by `MprisArtworkStore`.
  final Uri? artUrl;

  /// `xesam:url`, a `file://` URI. Source: `SongModel.path`.
  final Uri? url;

  const MprisTrack({
    required this.id,
    required this.title,
    this.artists = const [],
    this.album,
    this.length,
    this.artUrl,
    this.url,
  });

  @override
  List<Object?> get props => [id, title, artists, album, length, artUrl, url];
}

/// Everything MPRIS clients can see about the player, except Position
/// (which clients poll; see `MprisPlayerControl.position`).
///
/// Shuffle and LoopStatus are optional in the spec and not exposed yet
/// (the app has shuffle and repeat; they can be added later). Volume is
/// reported as a fixed 1.0.
class MprisPlayerState extends Equatable {
  final MprisPlaybackStatus status;
  final MprisTrack? track;
  final bool canGoNext;
  final bool canGoPrevious;
  final bool canSeek;

  const MprisPlayerState({
    this.status = MprisPlaybackStatus.stopped,
    this.track,
    this.canGoNext = false,
    this.canGoPrevious = false,
    this.canSeek = false,
  });

  @override
  List<Object?> get props => [status, track, canGoNext, canGoPrevious, canSeek];
}
