import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

SongModel song(String id) =>
    SongModel(id: id, path: '/$id.mp3', title: 'Title $id', artist: 'a');

void main() {
  final list = List.generate(4, (i) => song('$i'));
  final queued = song('queued');

  test('nothing playing: the whole order is to come', () {
    final queue = PlaybackState(playbackList: list).queue;
    expect(queue.songs, list);
    expect(queue.currentIndex, -1);
  });

  test('played songs stay in the queue before the current one', () {
    final queue = PlaybackState(
      song: list[2],
      playbackList: list,
      currentIndex: 2,
      playNextQueue: [queued],
    ).queue;
    expect(queue.songs, [list[0], list[1], list[2], queued, list[3]]);
    expect(queue.currentIndex, 2);
  });

  test('while a "play next" song plays, the anchor counts as played', () {
    final queue = PlaybackState(
      song: queued,
      playbackList: list,
      currentIndex: 1,
      anchorPath: list[1].path,
    ).queue;
    expect(queue.songs, [list[0], list[1], queued, list[2], list[3]]);
    expect(queue.currentIndex, 2);
  });

  test('a current song outside the order comes first', () {
    final queue = PlaybackState(
      song: queued,
      playbackList: list,
      currentIndex: -1,
    ).queue;
    expect(queue.songs, [queued, ...list]);
    expect(queue.currentIndex, 0);
  });
}
