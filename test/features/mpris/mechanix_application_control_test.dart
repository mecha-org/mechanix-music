import 'package:flutter_test/flutter_test.dart';
import 'package:mechanix_music/core/services/window_activator.dart';
import 'package:mechanix_music/features/mpris/bridge/mechanix_application_control.dart';
import 'package:mocktail/mocktail.dart';

class MockWindowActivator extends Mock implements WindowActivator {}

void main() {
  test('cannot raise without a window activator', () async {
    final control = MechanixApplicationControl(onQuit: () async {});
    expect(control.canRaise, isFalse);
    await control.raise(); // no-op, must not throw
  });

  test('raise activates the window', () async {
    final activator = MockWindowActivator();
    when(() => activator.activate()).thenAnswer((_) async {});
    final control = MechanixApplicationControl(
      windowActivator: activator,
      onQuit: () async {},
    );

    expect(control.canRaise, isTrue);
    await control.raise();
    verify(() => activator.activate()).called(1);
  });

  test('quit calls onQuit', () async {
    var quits = 0;
    final control = MechanixApplicationControl(onQuit: () async => quits++);

    expect(control.canQuit, isTrue);
    await control.quit();
    expect(quits, 1);
  });
}
