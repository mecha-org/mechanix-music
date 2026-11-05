import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/core/utils/constants.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileScannerService {
  FileScannerService();

  /// Scans [dirPath] (non-recursive) for audio files.
  Future<Map<String, SongModel>> scanDirectory(String dirPath) async {
    final result = <String, SongModel>{};

    try {
      final dir = Directory(dirPath);
      final exists = await dir.exists();
      if (!exists) return result;

      await for (final entity in dir.list(recursive: false)) {
        try {
          if (entity is! File) continue;

          final ext = p.extension(entity.path).toLowerCase();
          if (!Constants.audioExt.contains(ext)) continue;

          final song = await buildSongModel(entity.path);
          if (song == null) continue;

          result[song.id] = song;
        } catch (fileError) {
          AppLogger.e(
            '[FileScannerService] Skipping file: '
            '${entity.path} — $fileError',
          );
          continue;
        }
      }
    } on FileSystemException catch (e) {
      AppLogger.e(
        '[FileScannerService] FileSystem error scanning "$dirPath": $e',
      );
      return result;
    } catch (e) {
      AppLogger.e(
        '[FileScannerService] Unexpected error scanning "$dirPath": $e',
      );
      return result;
    }

    return result;
  }

  Future<SongModel?> buildSongModel(String filePath) async {
    try {
      const uuid = Uuid();
      final id = uuid.v4();
      final fileName = p.basenameWithoutExtension(filePath);

      // Read metadata
      AudioMetadata? meta;

      try {
        final file = File(filePath);
        if (!await file.exists()) return null;
        meta = readMetadata(file, getImage: true);
      } catch (metaError) {
        AppLogger.i(
          '[FileScannerService] No metadata for "$filePath": $metaError',
        );
      }

      // Fields
      final title = meta?.title?.trim().isNotEmpty == true
          ? meta!.title!.trim()
          : fileName;

      final artist = meta?.artist?.trim().isNotEmpty == true
          ? meta!.artist!.trim()
          : 'Unknown Artist';

      final album = meta?.album?.trim().isNotEmpty == true
          ? meta!.album!.trim()
          : null;

      final duration = meta?.duration != null
          ? _formatDuration(meta!.duration!.inSeconds)
          : null;

      // Artwork: the embedded cover, kept as base64 (stored in the index).
      String? artworkBase64;
      final pictures = meta?.pictures;
      if (pictures != null && pictures.isNotEmpty) {
        final bytes = pictures.first.bytes;
        if (bytes.isNotEmpty) artworkBase64 = base64Encode(bytes);
      }

      return SongModel(
        id: id,
        path: filePath,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artworkBase64: artworkBase64,
      );
    } on FileSystemException catch (e) {
      AppLogger.i('[FileScannerService] Cannot read file "$filePath": $e');
      return null;
    } catch (e) {
      AppLogger.e(
        '[FileScannerService] Failed to build model for "$filePath": $e',
      );
      return null;
    }
  }

  // Utils
  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
