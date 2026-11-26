import 'dart:async';

import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';
import 'package:pulseaudio/pulseaudio.dart';

/// Lists the audio outputs and switches between them through PulseAudio
/// The output is the PulseAudio default sink: picking one here sets the
/// default, as Settings → Sound → Output device does.
class AudioOutputService {
  AudioOutputService({PulseAudioClient? client})
    : _client = client ?? PulseAudioClient();

  final PulseAudioClient _client;
  Future<void>? _connecting;

  /// Connects once; a failed connection is retried on the next call.
  Future<void> _ensureConnected() async {
    final connecting = _connecting ??= _client.initialize();
    try {
      await connecting;
    } catch (_) {
      if (identical(_connecting, connecting)) _connecting = null;
      rethrow;
    }
  }

  /// Fires when an output appears, disappears or changes, or the default
  /// output changes (also from the Settings app), so a shown list can be
  /// reloaded.
  Stream<void> get changes {
    final subscriptions = <StreamSubscription<Object?>>[];
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () async {
        try {
          await _ensureConnected();
        } catch (_) {
          await controller.close();
          return;
        }
        for (final events in <Stream<Object?>>[
          _client.onSinkChanged,
          _client.onSinkRemoved,
          _client.onServerInfoChanged,
        ]) {
          subscriptions.add(events.listen((_) => controller.add(null)));
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// All outputs, the current (default) one marked [AudioOutput.isSelected].
  /// Empty when PulseAudio cannot be reached.
  Future<List<AudioOutput>> getOutputs() async {
    try {
      await _ensureConnected();
      final sinks = await _client.getSinkList();
      final selected = (await _client.getServerInfo()).defaultSinkName;
      return [
        for (final sink in sinks)
          ?toOutput(sink.name, sink.description, selectedName: selected),
      ];
    } catch (e) {
      AppLogger.e('[AudioOutputService] Listing outputs failed: $e');
      return const [];
    }
  }

  /// Plays audio on [output] (makes it the default output). Throws when
  /// switching fails.
  Future<void> select(AudioOutput output) async {
    await _ensureConnected();
    await _client.setDefaultSink(output.id);
    AppLogger.i('[AudioOutputService] Audio output: ${output.name}');
  }

  /// An [AudioOutput] for the sink [name] / [description], or null for sinks
  /// that are not real outputs (monitors, dummy and null sinks).
  static AudioOutput? toOutput(
    String name,
    String description, {
    String? selectedName,
  }) {
    if (name.isEmpty ||
        name.contains('.monitor') ||
        name == 'auto_null' ||
        name.contains('null-sink')) {
      return null;
    }
    final label = description.trim();
    return AudioOutput(
      id: name,
      name: label.isEmpty ? name : label,
      kind: kindOf(name, label),
      isSelected: name == selectedName,
    );
  }

  /// The kind of output, from its sink name and description (libpulse
  /// names follow `alsa_output.<card>.<profile>` / `bluez_output.<mac>…`).
  static AudioOutputKind kindOf(String name, String description) {
    final text = '$name $description'.toLowerCase();
    final isHeadphones =
        text.contains('headphone') ||
        text.contains('headset') ||
        text.contains('hands-free') ||
        text.contains('handsfree');

    if (name.startsWith('bluez_') || text.contains('bluetooth')) {
      return isHeadphones
          ? AudioOutputKind.headphones
          : AudioOutputKind.bluetooth;
    }
    if (text.contains('hdmi') ||
        text.contains('displayport') ||
        text.contains('display port')) {
      return AudioOutputKind.display;
    }
    if (isHeadphones) return AudioOutputKind.headphones;
    if (text.contains('usb')) return AudioOutputKind.usb;
    if (name.startsWith('alsa_output.') ||
        text.contains('built-in') ||
        text.contains('internal') ||
        text.contains('speaker')) {
      return AudioOutputKind.internal;
    }
    return AudioOutputKind.other;
  }
}
