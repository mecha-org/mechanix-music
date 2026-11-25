import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';
import 'package:mechanix_music/features/mpris/mappers/playback_state_mapper.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

SongModel song(String id, {String? album}) => SongModel(
  id: id,
  path: '/music/$id.mp3',
  title: 'Title $id',
  artist: 'Artist $id',
  album: album,
);

void main() {
  group('mapStatus', () {
    const expected = {
      PlaybackStatus.initial: MprisPlaybackStatus.stopped,
      PlaybackStatus.loading: MprisPlaybackStatus.playing,
      PlaybackStatus.playing: MprisPlaybackStatus.playing,
      PlaybackStatus.paused: MprisPlaybackStatus.paused,
      PlaybackStatus.stopped: MprisPlaybackStatus.stopped,
      PlaybackStatus.failure: MprisPlaybackStatus.stopped,
    };

    for (final status in PlaybackStatus.values) {
      test('$status -> ${expected[status]}', () {
        expect(PlaybackStateMapper.mapStatus(status), expected[status]);
      });
    }
  });

  group('mapSong', () {
    test('null song gives null track', () {
      expect(PlaybackStateMapper.mapSong(null, Duration.zero), isNull);
    });

    test('maps song fields', () {
      final art = Uri.file('/run/user/1000/art.png');
      final track = PlaybackStateMapper.mapSong(
        song('1', album: 'Album'),
        const Duration(minutes: 3),
        artUrl: art,
      )!;

      expect(track.id, '1');
      expect(track.title, 'Title 1');
      expect(track.artists, ['Artist 1']);
      expect(track.album, 'Album');
      expect(track.length, const Duration(minutes: 3));
      expect(track.artUrl, art);
      expect(track.url, Uri.file('/music/1.mp3'));
      expect(track.url!.scheme, 'file');
    });

    test('zero duration gives null length', () {
      final track = PlaybackStateMapper.mapSong(song('1'), Duration.zero)!;
      expect(track.length, isNull);
    });

    test('empty album and artist are left out', () {
      final s = song('1', album: '')..artist = '';
      final track = PlaybackStateMapper.mapSong(s, Duration.zero)!;
      expect(track.album, isNull);
      expect(track.artists, isEmpty);
    });
  });

  group('toMpris', () {
    final songs = [song('0'), song('1'), song('2')];

    test('empty state is stopped with no track', () {
      expect(
        PlaybackStateMapper.toMpris(const PlaybackState()),
        const MprisPlayerState(),
      );
    });

    test('hasNext / hasPrevious map to canGoNext / canGoPrevious', () {
      final middle = PlaybackStateMapper.toMpris(
        PlaybackState(song: songs[1], playbackList: songs, currentIndex: 1),
      );
      expect(middle.canGoNext, isTrue);
      expect(middle.canGoPrevious, isTrue);

      final first = PlaybackStateMapper.toMpris(
        PlaybackState(song: songs[0], playbackList: songs, currentIndex: 0),
      );
      expect(first.canGoPrevious, isFalse);

      final last = PlaybackStateMapper.toMpris(
        PlaybackState(song: songs[2], playbackList: songs, currentIndex: 2),
      );
      expect(last.canGoNext, isFalse);
    });

    test('canSeek needs a song and a known duration', () {
      final unknown = PlaybackStateMapper.toMpris(
        PlaybackState(song: songs[0], playbackList: songs),
      );
      expect(unknown.canSeek, isFalse);
      expect(unknown.track!.length, isNull);

      final known = PlaybackStateMapper.toMpris(
        PlaybackState(
          song: songs[0],
          playbackList: songs,
          songDuration: const Duration(seconds: 90),
        ),
      );
      expect(known.canSeek, isTrue);
      expect(known.track!.length, const Duration(seconds: 90));
    });

    test('status and artwork are passed through', () {
      final art = Uri.file('/tmp/a.jpg');
      final mapped = PlaybackStateMapper.toMpris(
        PlaybackState(status: PlaybackStatus.paused, song: songs[0]),
        artUrl: art,
      );
      expect(mapped.status, MprisPlaybackStatus.paused);
      expect(mapped.track!.artUrl, art);
    });
  });
}
