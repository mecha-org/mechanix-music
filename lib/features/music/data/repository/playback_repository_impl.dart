import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:mechanix_music/core/exceptions/app_exceptions.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

class PlaybackRepositoryImpl extends PlaybackRepository {
  PlaybackRepositoryImpl({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer() {
    // Replaces default FramePositionUpdater (60 calls/sec) with timer-based (2 calls/sec)
    _audioPlayer.positionUpdater = TimerPositionUpdater(
      getPosition: () async =>
          (await _audioPlayer.getCurrentPosition()) ?? Duration.zero,
      interval: const Duration(milliseconds: 500),
    );
  }

  final AudioPlayer _audioPlayer;

  @override
  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  @override
  Future<void> play(String url) async {
    try {
      if (await File(url).exists()) {
        await _audioPlayer.play(DeviceFileSource(url));
      } else {
        throw PlaybackFileNotFoundException('Playback file not found: $url');
      }
    } catch (e) {
      AppLogger.e('[PlaybackRepositoryImpl] Error playing audio: $e');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      AppLogger.e('[PlaybackRepositoryImpl] Error pausing audio: $e');
      rethrow;
    }
  }

  @override
  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
    } catch (e) {
      AppLogger.e('[PlaybackRepositoryImpl] Error resuming audio: $e');
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      AppLogger.e('[PlaybackRepositoryImpl] Error seeking audio: $e');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      AppLogger.e('[PlaybackRepositoryImpl] Error stopping audio: $e');
      rethrow;
    }
  }

  @override
  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  @override
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;

  @override
  Stream<void> get onSongComplete => _audioPlayer.onPlayerComplete;

  @override
  Stream<void> get onSeekComplete => _audioPlayer.onSeekComplete;

  @override
  Future<Duration?> getDuration() => _audioPlayer.getDuration();

  @override
  Future<Duration?> getCurrentPosition() => _audioPlayer.getCurrentPosition();

  @override
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
