import 'dart:convert';
import 'dart:io';

import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';

/// Runs a command and returns its result (replaceable in tests).
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Lists and switches audio outputs with `pactl`, which talks to
/// PulseAudio or PipeWire (through pipewire-pulse).
///
/// The app plays through GStreamer, which uses the default output, so
/// switching sets the default output and moves this app's playing streams
/// to it right away.
class AudioOutputService {
  AudioOutputService({ProcessRunner? run, int? processId})
    : _run = run ?? Process.run,
      _pid = processId ?? pid;

  final ProcessRunner _run;
  final int _pid;

  /// All outputs, the current one marked [AudioOutput.isSelected]. Empty
  /// when `pactl` is missing or fails.
  Future<List<AudioOutput>> getOutputs() async {
    try {
      final sinks = await _json(['list', 'sinks']);
      final selected = await _defaultSink();
      return [
        for (final sink in sinks.whereType<Map<String, dynamic>>())
          ?parseSink(sink, selectedId: selected),
      ];
    } catch (e) {
      AppLogger.e('[AudioOutputService] Listing outputs failed: $e');
      return const [];
    }
  }

  /// Plays audio on [output]. Throws when switching fails.
  Future<void> select(AudioOutput output) async {
    await _pactl(['set-default-sink', output.id]);

    // Move this app's streams too, in case they were pinned to a sink.
    try {
      final inputs = await _json(['list', 'sink-inputs']);
      for (final input in inputs.whereType<Map<String, dynamic>>()) {
        final props = input['properties'];
        final owner = props is Map ? props['application.process.id'] : null;
        if (owner?.toString() != _pid.toString()) continue;
        await _pactl(['move-sink-input', '${input['index']}', output.id]);
      }
    } catch (e) {
      // The default output changed; streams follow it on PipeWire.
      AppLogger.e('[AudioOutputService] Moving streams failed: $e');
    }
    AppLogger.i('[AudioOutputService] Audio output: ${output.name}');
  }

  Future<String?> _defaultSink() async {
    try {
      final name = (await _pactl(['get-default-sink'])).trim();
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Older pactl without get-default-sink: read it from `pactl info`.
    }
    final info = await _pactl(['info']);
    for (final line in const LineSplitter().convert(info)) {
      if (line.startsWith('Default Sink:')) {
        return line.substring('Default Sink:'.length).trim();
      }
    }
    return null;
  }

  Future<List<dynamic>> _json(List<String> args) async {
    final decoded = jsonDecode(await _pactl(['-f', 'json', ...args]));
    return decoded is List ? decoded : const [];
  }

  Future<String> _pactl(List<String> args) async {
    final result = await _run('pactl', args);
    if (result.exitCode != 0) {
      throw ProcessException(
        'pactl',
        args,
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return '${result.stdout}';
  }

  /// An [AudioOutput] for a `pactl -f json list sinks` entry, or null for
  /// sinks that are not real outputs (monitors, dummy and null sinks).
  static AudioOutput? parseSink(
    Map<String, dynamic> sink, {
    String? selectedId,
  }) {
    final id = sink['name'];
    if (id is! String || id.isEmpty) return null;
    final props = sink['properties'] is Map
        ? (sink['properties'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final factory = '${props['factory.name'] ?? ''}';
    if (id == 'auto_null' || factory.contains('null-audio-sink')) return null;

    final description = '${sink['description'] ?? ''}'.trim();
    return AudioOutput(
      id: id,
      name: description.isEmpty ? id : description,
      kind: _kind(id, sink, props),
      isSelected: id == selectedId,
    );
  }

  static AudioOutputKind _kind(
    String id,
    Map<String, dynamic> sink,
    Map<String, dynamic> props,
  ) {
    final bus = '${props['device.bus'] ?? ''}'.toLowerCase();
    final formFactor = '${props['device.form_factor'] ?? ''}'.toLowerCase();
    final port = '${sink['active_port'] ?? ''}'.toLowerCase();
    final text = '$id ${sink['description'] ?? ''} $port'.toLowerCase();

    final isHeadphones =
        formFactor == 'headphone' ||
        formFactor == 'headset' ||
        formFactor == 'hands-free' ||
        port.contains('headphone') ||
        port.contains('headset');

    if (bus == 'bluetooth' || id.startsWith('bluez_')) {
      return isHeadphones
          ? AudioOutputKind.headphones
          : AudioOutputKind.bluetooth;
    }
    if (text.contains('hdmi') ||
        text.contains('displayport') ||
        formFactor == 'tv' ||
        formFactor == 'monitor') {
      return AudioOutputKind.display;
    }
    if (isHeadphones) return AudioOutputKind.headphones;
    if (bus == 'usb') return AudioOutputKind.usb;
    if (formFactor == 'internal' || bus == 'pci' || id.startsWith('alsa_')) {
      return AudioOutputKind.internal;
    }
    return AudioOutputKind.other;
  }
}
