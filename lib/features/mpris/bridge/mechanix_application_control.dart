import 'package:flutter/services.dart';
import 'package:mechanix_music/core/services/window_activator.dart';
import 'package:mechanix_music/features/mpris/data/mpris_controls.dart';

/// [MprisApplicationControl] for the Mechanix shell.
///
/// raise → [WindowActivator.activate]. quit → [onQuit], by default
/// `SystemNavigator.pop()` (the app has no close button of its own; the
/// shell closes it). [canRaise] is false when no activator is available, so
/// clients hide their "show player" action instead of offering a dead one.
class MechanixApplicationControl implements MprisApplicationControl {
  MechanixApplicationControl({
    WindowActivator? windowActivator,
    Future<void> Function()? onQuit,
  }) : _windowActivator = windowActivator,
       _onQuit = onQuit ?? SystemNavigator.pop;

  final WindowActivator? _windowActivator;
  final Future<void> Function() _onQuit;

  @override
  bool get canRaise => _windowActivator != null;

  @override
  bool get canQuit => true;

  @override
  Future<void> raise() async {
    await _windowActivator?.activate();
  }

  @override
  Future<void> quit() => _onQuit();
}
