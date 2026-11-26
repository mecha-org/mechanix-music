import 'package:equatable/equatable.dart';

/// What kind of device an [AudioOutput] plays on; decides its icon.
enum AudioOutputKind {
  /// The device's own speaker or audio jack.
  internal,

  /// A monitor or TV over HDMI / DisplayPort.
  display,

  /// Headphones or a headset (wired or Bluetooth).
  headphones,

  /// A Bluetooth speaker or other Bluetooth audio device.
  bluetooth,

  /// A USB audio device.
  usb,

  /// Anything else.
  other,
}

/// An audio output (a PulseAudio / PipeWire sink).
class AudioOutput extends Equatable {
  const AudioOutput({
    required this.id,
    required this.name,
    required this.kind,
    this.isSelected = false,
  });

  /// Sink name, used to switch to this output.
  final String id;

  /// Display name (the sink's description).
  final String name;

  final AudioOutputKind kind;

  /// Whether this is the output audio currently plays on.
  final bool isSelected;

  AudioOutput copyWith({String? name, bool? isSelected}) => AudioOutput(
    id: id,
    name: name ?? this.name,
    kind: kind,
    isSelected: isSelected ?? this.isSelected,
  );

  @override
  List<Object?> get props => [id, name, kind, isSelected];
}
