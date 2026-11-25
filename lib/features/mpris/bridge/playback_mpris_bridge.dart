import 'dart:async';

import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/mpris/data/mpris_artwork_store.dart';
import 'package:mechanix_music/features/mpris/data/mpris_controls.dart';
import 'package:mechanix_music/features/mpris/data/server/mpris_server.dart';
import 'package:mechanix_music/features/mpris/mappers/playback_state_mapper.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

/// Connects the existing playback feature to an [MprisServer].
///
/// Commands in (MPRIS → app), as `PlaybackEvent`s on the bloc, exactly what
/// the UI would send:
///
/// | MPRIS call | PlaybackEvent                                              |
/// | ---------- | ---------------------------------------------------------- |
/// | play       | `PlaybackResume` if a song is paused; otherwise            |
/// |            | `PlaybackPlay(playbackList[currentIndex])` if list ≠ empty |
/// | pause      | `PlaybackPause`                                            |
/// | playPause  | pause if status is playing/loading, else play              |
/// | stop       | `PlaybackStop`                                             |
/// | next       | `PlaybackPlayNext`                                         |
/// | previous   | `PlaybackPlayPrevious`                                     |
/// | seekTo     | `PlaybackSeek`                                             |
///
/// State out (app → MPRIS), all from streams that already exist:
///
/// | Source                                 | Server call                    |
/// | -------------------------------------- | ------------------------------ |
/// | `PlaybackBloc.stream`                  | `publish(mapper.toMpris(...))` |
/// | `PlaybackRepository.onSeekComplete`    | `notifySeeked(position)`       |
/// | `PlaybackRepository.onPositionChanged` | updates the cached [position]  |
///
/// The bridge never publishes in response to a command: a remote pause and
/// a UI pause both reach clients through the bloc's next state.
class PlaybackMprisBridge implements MprisPlayerControl {
  PlaybackMprisBridge({
    required PlaybackBloc playbackBloc,
    required PlaybackRepository playbackRepository,
    MprisArtworkStore? artworkStore,
  }) : _bloc = playbackBloc,
       _repository = playbackRepository,
       _artworkStore = artworkStore ?? FileMprisArtworkStore();

  final PlaybackBloc _bloc;
  final PlaybackRepository _repository;
  final MprisArtworkStore _artworkStore;

  MprisServer? _server;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  Duration _position = Duration.zero;

  /// Path of the song last published, to reset [position] on track change.
  String? _publishedSongPath;

  /// Subscribe to the bloc and repository streams and publish the current
  /// state once, so clients don't see an empty player until the next change.
  void attach(MprisServer server) {
    if (_server != null) {
      throw StateError('PlaybackMprisBridge is already attached');
    }
    _server = server;
    _subscriptions
      ..add(_bloc.stream.listen(_publish))
      ..add(_repository.onPositionChanged.listen((p) => _position = p))
      ..add(_repository.onSeekComplete.listen((_) => _onSeekComplete()));
    _publish(_bloc.state);
  }

  /// Cancel every subscription. Does not dispose the server.
  Future<void> detach() async {
    _server = null;
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(subscriptions.map((s) => s.cancel()));
  }

  void _publish(PlaybackState state) {
    final server = _server;
    if (server == null) return;

    final song = state.song;
    if (song?.path != _publishedSongPath) {
      // A new track starts at zero; the player reports progress from there.
      _publishedSongPath = song?.path;
      _position = Duration.zero;
    }

    final artUrl = song == null ? null : _artworkStore.uriFor(song);
    server.publish(PlaybackStateMapper.toMpris(state, artUrl: artUrl));
  }

  /// The cached position is refreshed every 500 ms, so right after a seek
  /// it is stale: read the real position before telling clients.
  Future<void> _onSeekComplete() async {
    try {
      final current = await _repository.getCurrentPosition();
      if (current != null) _position = current;
    } catch (e) {
      AppLogger.e('[PlaybackMprisBridge] Could not read position: $e');
    }
    _server?.notifySeeked(_position);
  }

  @override
  Future<void> play() async {
    final state = _bloc.state;
    if (state.song != null && state.status == PlaybackStatus.paused) {
      _bloc.add(const PlaybackResume());
      return;
    }
    if (_isPlaying(state.status)) return;

    final list = state.playbackList;
    if (list.isEmpty) return;
    final index = state.currentIndex;
    final song = index >= 0 && index < list.length ? list[index] : list.first;
    _bloc.add(PlaybackPlay(song));
  }

  @override
  Future<void> pause() async => _bloc.add(const PlaybackPause());

  @override
  Future<void> playPause() =>
      _isPlaying(_bloc.state.status) ? pause() : play();

  @override
  Future<void> stop() async => _bloc.add(const PlaybackStop());

  @override
  Future<void> next() async => _bloc.add(const PlaybackPlayNext());

  @override
  Future<void> previous() async => _bloc.add(const PlaybackPlayPrevious());

  @override
  Future<void> seekTo(Duration position) async =>
      _bloc.add(PlaybackSeek(position));

  @override
  Duration get position => _position;

  static bool _isPlaying(PlaybackStatus status) =>
      status == PlaybackStatus.playing || status == PlaybackStatus.loading;
}
