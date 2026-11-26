import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/features/music/data/models/audio_output.dart';
import 'package:mechanix_music/features/music/data/services/audio_output_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pulseaudio/pulseaudio.dart';

class MockPulseAudioClient extends Mock implements PulseAudioClient {}

PulseAudioSink sink(int index, String name, String description) =>
    PulseAudioSink(
      index: index,
      name: name,
      description: description,
      mute: false,
      volume: 1,
    );

void main() {
  const builtIn = 'alsa_output.platform-sound.stereo-fallback';
  const hdmi = 'alsa_output.platform-hdmi.hdmi-stereo';
  const jbl = 'bluez_output.AA_BB_CC_DD_EE_FF.1';

  late MockPulseAudioClient client;
  late StreamController<PulseAudioSink> sinkChanged;
  late StreamController<int> sinkRemoved;
  late StreamController<PulseAudioServerInfo> serverInfoChanged;
  late AudioOutputService service;

  PulseAudioServerInfo serverInfo(String defaultSink) => PulseAudioServerInfo(
    name: 'PulseAudio (on PipeWire)',
    version: '15.0.0',
    defaultSinkName: defaultSink,
    defaultSourceName: '',
  );

  setUp(() {
    client = MockPulseAudioClient();
    sinkChanged = StreamController.broadcast();
    sinkRemoved = StreamController.broadcast();
    serverInfoChanged = StreamController.broadcast();
    when(() => client.initialize()).thenAnswer((_) async {});
    when(() => client.getSinkList()).thenAnswer(
      (_) async => [
        sink(1, builtIn, 'Built-in Audio Stereo'),
        sink(2, hdmi, 'HDMI Audio'),
        sink(3, jbl, 'JBL speaker'),
        sink(4, '$hdmi.monitor', 'Monitor of HDMI Audio'),
        sink(5, 'auto_null', 'Dummy Output'),
      ],
    );
    when(
      () => client.getServerInfo(),
    ).thenAnswer((_) async => serverInfo(hdmi));
    when(() => client.setDefaultSink(any())).thenAnswer((_) async {});
    when(() => client.onSinkChanged).thenAnswer((_) => sinkChanged.stream);
    when(() => client.onSinkRemoved).thenAnswer((_) => sinkRemoved.stream);
    when(
      () => client.onServerInfoChanged,
    ).thenAnswer((_) => serverInfoChanged.stream);
    service = AudioOutputService(client: client);
  });

  test('lists real outputs with their kind and the default one', () async {
    final outputs = await service.getOutputs();

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
    verify(() => client.initialize()).called(1);
  });

  test('select makes the output the default, as Settings does', () async {
    final speaker = (await service.getOutputs()).last;

    await service.select(speaker);

    verify(() => client.setDefaultSink(jbl)).called(1);
  });

  test('no outputs when PulseAudio cannot be reached', () async {
    when(() => client.initialize()).thenThrow(Exception('no server'));

    expect(await service.getOutputs(), isEmpty);
  });

  test('a failed connection is retried', () async {
    var attempts = 0;
    when(() => client.initialize()).thenAnswer((_) async {
      if (attempts++ == 0) throw Exception('not yet');
    });

    expect(await service.getOutputs(), isEmpty);
    expect(await service.getOutputs(), hasLength(3));
  });

  test('changes fires for output and default-output changes', () async {
    var count = 0;
    final sub = service.changes.listen((_) => count++);
    await pumpEventQueue();

    sinkChanged.add(sink(3, jbl, 'JBL speaker'));
    sinkRemoved.add(3);
    serverInfoChanged.add(serverInfo(builtIn));
    await pumpEventQueue();

    expect(count, 3);
    await sub.cancel();
  });

  group('kindOf', () {
    test('recognises the usual sink names', () {
      expect(
        AudioOutputService.kindOf('bluez_output.X.a2dp-sink', 'Earbuds'),
        AudioOutputKind.bluetooth,
      );
      expect(
        AudioOutputService.kindOf('bluez_output.X', 'Headset'),
        AudioOutputKind.headphones,
      );
      expect(
        AudioOutputService.kindOf(
          'alsa_output.pci.analog-stereo',
          'Headphones',
        ),
        AudioOutputKind.headphones,
      );
      expect(
        AudioOutputService.kindOf('alsa_output.usb-Foo.analog', 'USB Audio'),
        AudioOutputKind.usb,
      );
      expect(
        AudioOutputService.kindOf('something', 'Network sink'),
        AudioOutputKind.other,
      );
    });
  });
}
