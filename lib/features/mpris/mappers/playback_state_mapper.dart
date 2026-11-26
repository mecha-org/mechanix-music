import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

/// Pure translation from the app's playback model to the MPRIS model.
/// No I/O, no D-Bus: unit-test every row of the tables below.
abstract final class PlaybackStateMapper {
  /// `PlaybackState` → `MprisPlayerState`:
  ///
  /// | MPRIS          | From                                        |
  /// | -------------- | ------------------------------------------- |
  /// | status         | [mapStatus] of `state.status`               |
  /// | track          | [mapSong] of `state.song`, `songDuration`   |
  /// | canGoNext      | `state.hasNext`                             |
  /// | canGoPrevious  | `state.hasPrevious`                         |
  /// | canSeek        | song present and `songDuration > zero`      |
  ///
  /// [artUrl] is the `file://` URI of the current song's artwork. Songs
  /// keep artwork as base64, so the caller writes it to a file first
  /// (see `MprisArtworkStore`) to keep this mapper free of I/O.
  static MprisPlayerState toMpris(PlaybackState state, {Uri? artUrl}) {
    final song = state.song;
    return MprisPlayerState(
      status: mapStatus(state.status),
      track: mapSong(song, state.songDuration, artUrl: artUrl),
      canGoNext: state.hasNext,
      canGoPrevious: state.hasPrevious,
      canSeek: song != null && state.songDuration > Duration.zero,
    );
  }

  /// | PlaybackStatus | MprisPlaybackStatus | Why                                  |
  /// | -------------- | ------------------- | ------------------------------------ |
  /// | initial        | stopped             | nothing loaded yet                   |
  /// | loading        | playing             | a track was asked for; avoids a      |
  /// |                |                     | Stopped flicker between tracks       |
  /// | playing        | playing             |                                      |
  /// | paused         | paused              |                                      |
  /// | stopped        | stopped             |                                      |
  /// | failure        | stopped             | the bloc may auto-advance afterwards |
  static MprisPlaybackStatus mapStatus(PlaybackStatus status) =>
      switch (status) {
        PlaybackStatus.initial => MprisPlaybackStatus.stopped,
        PlaybackStatus.loading => MprisPlaybackStatus.playing,
        PlaybackStatus.playing => MprisPlaybackStatus.playing,
        PlaybackStatus.paused => MprisPlaybackStatus.paused,
        PlaybackStatus.stopped => MprisPlaybackStatus.stopped,
        PlaybackStatus.failure => MprisPlaybackStatus.stopped,
      };

  /// `SongModel` → `MprisTrack`. Null song → null track (clients then see
  /// the spec's NoTrack id). [duration] ≤ zero → `length` is null.
  static MprisTrack? mapSong(
    SongModel? song,
    Duration duration, {
    Uri? artUrl,
  }) {
    if (song == null) return null;
    final album = song.album;
    return MprisTrack(
      id: song.id,
      title: song.title,
      artists: song.artist.isEmpty ? const [] : [song.artist],
      album: album == null || album.isEmpty ? null : album,
      length: duration > Duration.zero ? duration : null,
      artUrl: artUrl,
      url: Uri.file(song.path),
    );
  }
}
