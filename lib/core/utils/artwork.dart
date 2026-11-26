import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// Turns a song's `artworkBase64` into an image.
///
/// Decoded bytes are kept for the most recently shown covers, so lists and
/// the player do not decode the same base64 string on every build, and the
/// same [MemoryImage] (same bytes) is reused, which keeps Flutter's image
/// cache effective.
class ArtworkCache {
  ArtworkCache._();

  static const _maxEntries = 64;

  // Insertion-ordered: the first key is the least recently used.
  static final Map<String, Uint8List?> _bytes = {};

  /// Decoded bytes of [base64], or null when it is empty or invalid.
  static Uint8List? decode(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    if (_bytes.containsKey(base64)) {
      final bytes = _bytes.remove(base64);
      _bytes[base64] = bytes; // mark as most recently used
      return bytes;
    }
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64);
    } on FormatException {
      bytes = null;
    }
    _bytes[base64] = bytes;
    if (_bytes.length > _maxEntries) _bytes.remove(_bytes.keys.first);
    return bytes;
  }

  /// Image of [base64], or null when there is no (valid) artwork.
  static ImageProvider? image(String? base64) {
    final bytes = decode(base64);
    return bytes == null ? null : MemoryImage(bytes);
  }
}
