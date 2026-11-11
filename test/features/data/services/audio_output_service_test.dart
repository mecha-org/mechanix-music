import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';
import 'package:mechanix_music/features/music/data/services/audio_output_service.dart';

void main() {
  final sinks = [
    {
      'index': 1,
      'name': 'alsa_output.platform-sound.stereo-fallback',
      'description': 'Built-in Audio Stereo',
      'active_port': 'analog-output-speaker',
      'properties': {'device.bus': 'platform', 'device.form_factor': 'internal'},
    },
    {
      'index': 2,
      'name': 'alsa_output.platform-hdmi.hdmi-stereo',
      'description': 'HDMI Audio',
      'active_port': 'hdmi-output-0',
      'properties': <String, dynamic>{},
    },
    {
      'index': 3,
      'name': 'bluez_output.AA_BB_CC_DD_EE_FF.1',
      'description': 'JBL speaker',
      'properties': {'device.bus': 'bluetooth', 'device.form_factor': 'speaker'},
    },
    {
      'index': 4,
      'name': 'auto_null',
      'description': 'Dummy Output',
      'properties': <String, dynamic>{},
    },
  ];

  late List<List<String>> calls;

  AudioOutputService service({
    String defaultSink = 'alsa_output.platform-hdmi.hdmi-stereo',
    List<Map<String, dynamic>> inputs = const [],
  }) {
    calls = [];
    return AudioOutputService(
      processId: 42,
      run: (executable, args) async {
        calls.add(args);
        final out = switch (args.join(' ')) {
          '-f json list sinks' => jsonEncode(sinks),
          '-f json list sink-inputs' => jsonEncode(inputs),
          'get-default-sink' => '$defaultSink\n',
          _ => '',
        };
        return ProcessResult(0, 0, out, '');
      },
    );
  }

  test('lists outputs with kind and the selected one', () async {
    final outputs = await service().getOutputs();

    expect(outputs.map((o) => o.name), [
      'Built-in Audio Stereo',
      'HDMI Audio',
      'JBL speaker',
    ]);
    expect(outputs.map((o) => o.kind), [
      AudioOutputKind.internal,
      AudioOutputKind.display,
      AudioOutputKind.bluetooth,
    ]);
    expect(outputs.map((o) => o.isSelected), [false, true, false]);
  });

  test('select sets the default and moves only this app\'s streams', () async {
    final s = service(
      inputs: [
        {
          'index': 7,
          'properties': {'application.process.id': '42'},
        },
        {
          'index': 8,
          'properties': {'application.process.id': '99'},
        },
      ],
    );
    final jbl = (await s.getOutputs()).last;
    calls.clear();

    await s.select(jbl);

    expect(calls, [
      ['set-default-sink', 'bluez_output.AA_BB_CC_DD_EE_FF.1'],
      ['-f', 'json', 'list', 'sink-inputs'],
      ['move-sink-input', '7', 'bluez_output.AA_BB_CC_DD_EE_FF.1'],
    ]);
  });

  test('no outputs when pactl is missing', () async {
    final s = AudioOutputService(
      run: (_, args) async => throw ProcessException('pactl', args),
    );
    expect(await s.getOutputs(), isEmpty);
  });
}
