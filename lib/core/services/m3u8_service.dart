import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One track of an [M3u8Playlist].
class M3u8Entry {
  const M3u8Entry({required this.path, this.durationSeconds, this.title});

  /// Absolute path of the audio file.
  final String path;

  /// Length in seconds from `#EXTINF`, or null when unknown.
  final int? durationSeconds;

  /// Display title from `#EXTINF` (usually "Artist - Title").
  final String? title;
}

/// An extended M3U playlist (`.m3u8`, UTF-8).
class M3u8Playlist {
  const M3u8Playlist({this.name, this.createdAt, this.entries = const []});

  /// Name from `#PLAYLIST`, or null if the file has none.
  final String? name;

  /// Creation time from `#X-MECHANIX-CREATED`, or null if the file has none.
  final DateTime? createdAt;

  final List<M3u8Entry> entries;

  List<String> get paths => [for (final entry in entries) entry.path];

  static const _header = '#EXTM3U';
  static const _playlistTag = '#PLAYLIST:';
  static const _createdTag = '#X-MECHANIX-CREATED:';
  static const _extInfTag = '#EXTINF:';

  /// Parses [content]. Relative track paths are resolved against
  /// [baseDirectory] and `file://` URIs are turned into paths; other URLs
  /// (e.g. `http://`) are skipped.
  factory M3u8Playlist.parse(String content, {required String baseDirectory}) {
    String? name;
    DateTime? createdAt;
    int? pendingDuration;
    String? pendingTitle;
    final entries = <M3u8Entry>[];

    for (final rawLine in const LineSplitter().convert(content)) {
      // Drop a UTF-8 BOM and surrounding whitespace.
      final line = rawLine.replaceFirst('﻿', '').trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#')) {
        if (line.startsWith(_playlistTag)) {
          final value = line.substring(_playlistTag.length).trim();
          if (value.isNotEmpty) name = value;
        } else if (line.startsWith(_createdTag)) {
          createdAt = DateTime.tryParse(
            line.substring(_createdTag.length).trim(),
          )?.toUtc();
        } else if (line.startsWith(_extInfTag)) {
          final info = line.substring(_extInfTag.length);
          final comma = info.indexOf(',');
          final durationPart = comma == -1 ? info : info.substring(0, comma);
          // The duration may be followed by attributes (`-1 tvg-id="x"`).
          final seconds = int.tryParse(
            durationPart.trim().split(RegExp(r'\s')).first.split('.').first,
          );
          pendingDuration = seconds != null && seconds >= 0 ? seconds : null;
          final title = comma == -1 ? '' : info.substring(comma + 1).trim();
          pendingTitle = title.isEmpty ? null : title;
        }
        continue;
      }

      final path = _resolve(line, baseDirectory);
      if (path != null) {
        entries.add(
          M3u8Entry(
            path: path,
            durationSeconds: pendingDuration,
            title: pendingTitle,
          ),
        );
      }
      pendingDuration = null;
      pendingTitle = null;
    }

    return M3u8Playlist(name: name, createdAt: createdAt, entries: entries);
  }

  static String? _resolve(String location, String baseDirectory) {
    if (p.isAbsolute(location)) return p.normalize(location);
    if (location.toLowerCase().startsWith('file://')) {
      final uri = Uri.tryParse(location);
      return uri == null ? null : p.normalize(uri.toFilePath());
    }
    // Streams and other URLs are not local songs.
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(location)) return null;
    return p.normalize(p.join(baseDirectory, location));
  }

  /// The file content for this playlist.
  String serialize() {
    final buffer = StringBuffer()..writeln(_header);
    final name = this.name;
    if (name != null && name.isNotEmpty) {
      // A line break in the name would end the tag.
      buffer.writeln('$_playlistTag${_singleLine(name)}');
    }
    final createdAt = this.createdAt;
    if (createdAt != null) {
      buffer.writeln('$_createdTag${createdAt.toUtc().toIso8601String()}');
    }
    for (final entry in entries) {
      final title = entry.title;
      buffer.writeln(
        '$_extInfTag${entry.durationSeconds ?? -1},'
        '${title == null ? p.basenameWithoutExtension(entry.path) : _singleLine(title)}',
      );
      buffer.writeln(entry.path);
    }
    return buffer.toString();
  }

  static String _singleLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  M3u8Playlist copyWith({String? name, List<M3u8Entry>? entries}) =>
      M3u8Playlist(
        name: name ?? this.name,
        createdAt: createdAt,
        entries: entries ?? this.entries,
      );
}

/// Reads and writes [M3u8Playlist] files.
class M3u8Service {
  const M3u8Service();

  static const extension = '.m3u8';

  /// Reads the playlist at [file], or returns null if it does not exist.
  Future<M3u8Playlist?> read(File file) async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return M3u8Playlist.parse(
      utf8.decode(bytes, allowMalformed: true),
      baseDirectory: file.parent.path,
    );
  }

  /// Writes [playlist] to [file]. The content goes to a temporary file
  /// first and is then renamed over [file], so a crash never leaves a
  /// half-written playlist behind.
  Future<void> write(File file, M3u8Playlist playlist) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(playlist.serialize(), encoding: utf8, flush: true);
    await temp.rename(file.path);
  }

  /// All `.m3u8` files directly inside [directory], sorted by name.
  Future<List<File>> list(Directory directory) async {
    if (!await directory.exists()) return [];
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == extension) {
        files.add(entity);
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
