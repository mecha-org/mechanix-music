import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/enums.dart' show PlaybackStatus;
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';

/// App-wide keys: Space play/pause, ←/→ seek, Ctrl+←/→ previous/next,
/// Esc back. Text fields keep Space and the arrows. Pair with
/// [appShortcuts] on `MaterialApp`.
class MusicShortcuts extends StatefulWidget {
  const MusicShortcuts({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  static const seekStep = Duration(seconds: 10);

  // A list: a const set can't hold LogicalKeyboardKey (custom ==).
  static const _takenKeys = [
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  ];

  /// Default shortcuts with Space and ←/→ disabled, so they don't also
  /// press or move the focused widget. Defaults are removed, not
  /// overridden: [SingleActivator] has no `==`.
  static final Map<ShortcutActivator, Intent> appShortcuts = {
    for (final MapEntry(:key, :value) in WidgetsApp.defaultShortcuts.entries)
      if (!_isTaken(key)) key: value,
    for (final key in _takenKeys)
      SingleActivator(key): const DoNothingAndStopPropagationIntent(),
  };

  static bool _isTaken(ShortcutActivator activator) =>
      activator is SingleActivator &&
      _takenKeys.contains(activator.trigger) &&
      !activator.control &&
      !activator.alt &&
      !activator.shift &&
      !activator.meta;

  /// The app's navigator, for Esc.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<MusicShortcuts> createState() => _MusicShortcutsState();
}

class _MusicShortcutsState extends State<MusicShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// True when the event was used.
  bool _onKey(KeyEvent event) {
    if (event is KeyUpEvent || !mounted) return false;

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return false;
    }
    final ctrl = keyboard.isControlPressed;
    final isRepeat = event is KeyRepeatEvent;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      return !ctrl && !isRepeat && _back();
    }
    if (_isTyping) return false;

    final bloc = context.read<PlaybackBloc>();
    if (key == LogicalKeyboardKey.space && !ctrl) {
      return isRepeat ? bloc.state.song != null : _playPause(bloc);
    }

    final forward = key == LogicalKeyboardKey.arrowRight;
    if (!forward && key != LogicalKeyboardKey.arrowLeft) return false;
    if (bloc.state.song == null) return false;
    if (ctrl) {
      if (!isRepeat) {
        bloc.add(
          forward ? const PlaybackPlayNext() : const PlaybackPlayPrevious(),
        );
      }
    } else {
      bloc.add(
        PlaybackSeekBy(
          forward ? MusicShortcuts.seekStep : -MusicShortcuts.seekStep,
        ),
      );
    }
    return true;
  }

  /// Like the play button. False when there is nothing to play.
  bool _playPause(PlaybackBloc bloc) {
    final state = bloc.state;
    if (state.status == PlaybackStatus.playing ||
        state.status == PlaybackStatus.loading) {
      bloc.add(const PlaybackPause());
    } else if (state.song != null) {
      bloc.add(const PlaybackResume());
    } else if (state.upNext.firstOrNull case final first?) {
      bloc.add(PlaybackPlay(first));
    } else {
      return false;
    }
    return true;
  }

  /// False on the main screen.
  bool _back() {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    navigator.maybePop();
    return true;
  }

  /// Whether a text field has focus.
  static bool get _isTyping {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
