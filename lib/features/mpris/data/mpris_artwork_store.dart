import 'dart:io';

import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/artwork.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';

/// Gives MPRIS clients a `file://` URI for a song's artwork.
///
/// Songs keep their cover as base64 (`SongModel.artworkBase64`), but the
/// MPRIS `mpris:artUrl` must point at a file, so the cover is written to a
/// per-user cache folder the first time it is needed.
abstract interface class MprisArtworkStore {
  /// URI of [song]'s artwork, or null when it has none.
  Uri? uriFor(SongModel song);
}

/// [MprisArtworkStore] that writes covers to
/// `$XDG_RUNTIME_DIR/mechanix_music/mpris-art` (falls back to the system
/// temp folder). Only the most recent [maxFiles] covers are kept.
class FileMprisArtworkStore implements MprisArtworkStore {
  FileMprisArtworkStore({Directory? directory, this.maxFiles = 4})
    : _directory = directory ?? _defaultDirectory();

  final Directory _directory;
  final int maxFiles;

  /// Song id → written file, most recently used last.
  final Map<String, File> _files = {};

  static Directory _defaultDirectory() {
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    final base = runtimeDir != null && runtimeDir.isNotEmpty
        ? runtimeDir
        : Directory.systemTemp.path;
    return Directory('$base/mechanix_music/mpris-art');
  }

  @override
  Uri? uriFor(SongModel song) {
    final cached = _files.remove(song.id);
    if (cached != null) {
      _files[song.id] = cached; // mark as most recently used
      return cached.uri;
    }

    final bytes = ArtworkCache.decode(song.artworkBase64);
    if (bytes == null) return null;

    try {
      _directory.createSync(recursive: true);
      final file = File(
        '${_directory.path}/${_safeName(song.id)}${_extension(bytes)}',
      );
      file.writeAsBytesSync(bytes, flush: true);
      _files[song.id] = file;
      _evictOldFiles();
      return file.uri;
    } on FileSystemException catch (e) {
      AppLogger.e('[MprisArtworkStore] Could not write artwork: $e');
      return null;
    }
  }

  void _evictOldFiles() {
    while (_files.length > maxFiles) {
      final oldest = _files.remove(_files.keys.first)!;
      try {
        oldest.deleteSync();
      } on FileSystemException {
        // Already gone; nothing to clean up.
      }
    }
  }

  /// File-name-safe version of a song id.
  static String _safeName(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Extension from the image's magic bytes, so clients that look at the
  /// name pick the right decoder.
  static String _extension(List<int> bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return '.jpg';
    }
    return '.img';
  }
}
