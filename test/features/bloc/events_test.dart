// Events are created with `new` (not const) so their constructors run and
// count for coverage; const instances are built at compile time.
// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/utils/enums.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_event.dart';
import 'package:mechanix_music/features/music/bloc/search/search_event.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/data/models/playlist.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

void main() {
  final song = SongModel(id: '1', path: '/1.mp3', title: 'One', artist: 'A');
  final other = SongModel(id: '2', path: '/2.mp3', title: 'Two', artist: 'B');

  group('PlaybackEvent', () {
    test('events without fields are equal', () {
      expect(PlaybackPause(), PlaybackPause());
      expect(PlaybackResume(), PlaybackResume());
      expect(PlaybackStop(), PlaybackStop());
      expect(PlaybackPlayNext(), PlaybackPlayNext());
      expect(PlaybackPlayPrevious(), PlaybackPlayPrevious());
      expect(PlaybackToggleShuffle(), PlaybackToggleShuffle());
      expect(PlaybackCycleRepeatMode(), PlaybackCycleRepeatMode());
      expect(PlaybackSleepTimerElapsed(), PlaybackSleepTimerElapsed());
      expect(PlaybackPause().props, isEmpty);
    });

    test('events compare by their fields', () {
      expect(PlaybackPlay(song), PlaybackPlay(song));
      expect(PlaybackPlay(song), isNot(PlaybackPlay(song, fromQueue: true)));
      expect(PlaybackPlay(song).props, [song, false]);

      expect(
        PlaybackSeek(const Duration(seconds: 5)),
        PlaybackSeek(const Duration(seconds: 5)),
      );
      expect(
        PlaybackSeek(const Duration(seconds: 5)).props,
        [const Duration(seconds: 5)],
      );

      expect(PlaybackListUpdated([song]).props, [
        [song],
        true,
      ]);
      expect(
        PlaybackListUpdated([song], followsLibrary: false),
        isNot(PlaybackListUpdated([song])),
      );

      expect(PlaybackLibraryUpdated([song]).props, [
        [song],
      ]);
      expect(
        PlaybackDurationUpdated(const Duration(minutes: 1)).props,
        [const Duration(minutes: 1)],
      );
      expect(PlaybackQueueNext(song), PlaybackQueueNext(song));
      expect(PlaybackQueueNext(song), isNot(PlaybackQueueNext(other)));
      expect(
        PlaybackSetSleepTimer(SleepTimerOption.minutes5).props,
        [SleepTimerOption.minutes5],
      );
      expect(PlaybackSetSleepTimer(null).props, [null]);
    });
  });

  group('PlaylistEvent', () {
    test('events compare by their fields', () {
      expect(PlaylistsRequested(), PlaylistsRequested());
      expect(PlaylistsRequested().props, isEmpty);
      expect(
        PlaylistCreateRequested(created: Completer<Playlist>()).props,
        isEmpty,
      );
      expect(PlaylistRenamed('a', 'Road').props, ['a', 'Road']);
      expect(PlaylistRenamed('a', 'Road'), isNot(PlaylistRenamed('a', 'Mix')));
      expect(PlaylistSongAdded('a', '/1.mp3').props, ['a', '/1.mp3']);
      expect(PlaylistSongRemoved('a', '/1.mp3').props, ['a', '/1.mp3']);
      expect(PlaylistSongMoved('a', 0, 2).props, ['a', 0, 2]);
      expect(PlaylistSongMoved('a', 0, 2), PlaylistSongMoved('a', 0, 2));
    });
  });

  group('SearchEvent', () {
    test('events compare by their fields', () {
      expect(SearchStarted(), SearchStarted());
      expect(SearchStarted().props, isEmpty);
      expect(SearchQueryChanged('abc').props, ['abc']);
      expect(SearchSongOpened(song).props, ['/1.mp3']);
      expect(SearchRecentRemoved('/1.mp3').props, ['/1.mp3']);
      expect(SearchRecentsCleared(), SearchRecentsCleared());
    });
  });

  group('SongEvent', () {
    test('events compare by their fields', () {
      expect(SongInitialized(), SongInitialized());
      expect(SongInitialized().props, isEmpty);
      expect(SongLoadMore(), SongLoadMore());
      expect(SongSyncCompleted(), SongSyncCompleted());
      expect(SongUpsert(song).props, [song]);
      expect(SongDelete(song).props, [song]);
      expect(SongAddByPaths(['/1.mp3']).props, [
        ['/1.mp3'],
      ]);
      expect(SongToggleFavourite(song), SongToggleFavourite(song));
      expect(SongToggleFavourite(song), isNot(SongToggleFavourite(other)));
    });
  });
}
