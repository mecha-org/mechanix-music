import 'dart:io';

import 'package:mechanix_music/core/services/m3u8_service.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository.dart';
import 'package:path/path.dart' as p;

/// Recent searches kept as an `.m3u8` playlist (newest first), like the
/// favourites and the user playlists.
class RecentSearchRepositoryImpl implements RecentSearchRepository {
  RecentSearchRepositoryImpl({
    String Function()? filePathProvider,
    int limit = Constants.recentSearchesLimit,
    M3u8Service m3u8Service = const M3u8Service(),
  }) : _filePathProvider = filePathProvider ?? _defaultFilePath,
       _limit = limit,
       _m3u8 = m3u8Service;

  final String Function() _filePathProvider;
  final int _limit;
  final M3u8Service _m3u8;

  List<String>? _paths;

  static String _defaultFilePath() {
    final home = Platform.environment['HOME'] ?? '/home';
    return p.join(home, Constants.recentSearchesFilePath);
  }

  File get _file => File(_filePathProvider());

  Future<List<String>> _load() async {
    if (_paths case final paths?) return paths;
    try {
      return _paths = (await _m3u8.read(_file))?.paths ?? [];
    } catch (e) {
      AppLogger.e('[RecentSearchRepository] Could not read ${_file.path}: $e');
      return _paths = [];
    }
  }

  Future<void> _save(List<String> paths) async {
    _paths = paths;
    await _m3u8.write(
      _file,
      M3u8Playlist(
        name: 'Recent searches',
        entries: [for (final path in paths) M3u8Entry(path: path)],
      ),
    );
  }

  @override
  Future<List<String>> getRecentPaths() async => [...await _load()];

  @override
  Future<void> add(String path) async {
    final paths = [path, ...(await _load()).where((p) => p != path)];
    await _save(paths.take(_limit).toList());
  }

  @override
  Future<void> remove(String path) async {
    final paths = await _load();
    if (!paths.contains(path)) return;
    await _save(paths.where((p) => p != path).toList());
  }

  @override
  Future<void> clear() => _save([]);
}
