import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/helper.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/player/player_state.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

/// Seekable progress bar with elapsed / total time labels below it.
class LandingProgress extends StatelessWidget {
  const LandingProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      PlaybackBloc,
      PlaybackState,
      ({String? path, Duration duration})
    >(
      selector: (state) =>
          (path: state.song?.path, duration: state.songDuration),
      builder: (context, data) {
        // Keyed by song so the position resets when the song changes.
        return _PositionedProgress(
          key: ValueKey(data.path),
          hasSong: data.path != null,
          duration: data.duration,
        );
      },
    );
  }
}

class _PositionedProgress extends StatefulWidget {
  const _PositionedProgress({
    super.key,
    required this.hasSong,
    required this.duration,
  });

  final bool hasSong;
  final Duration duration;

  @override
  State<_PositionedProgress> createState() => _PositionedProgressState();
}

class _PositionedProgressState extends State<_PositionedProgress> {
  /// Fraction shown while the user drags, or null when not dragging.
  double? _dragFraction;

  /// Last position from the player.
  Duration _position = Duration.zero;

  StreamSubscription<Duration>? _positionSub;

  /// What the bar shows (0–1) and the elapsed label (whole seconds). Only
  /// the bar and that label listen, so position ticks rebuild nothing else
  /// (the layout, the gestures and the total-time label stay as they are).
  final _fraction = ValueNotifier<double>(0);
  final _elapsedSeconds = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    if (widget.hasSong) {
      _positionSub = context.read<PlaybackRepository>().onPositionChanged
          .listen((position) {
            _position = position;
            _update();
          });
    }
  }

  @override
  void didUpdateWidget(_PositionedProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) _update();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _fraction.dispose();
    _elapsedSeconds.dispose();
    super.dispose();
  }

  /// Pushes the shown position (the drag, or the player's) to the bar and
  /// the elapsed label.
  void _update() {
    final drag = _dragFraction;
    final shown = drag != null ? widget.duration * drag : _position;
    _fraction.value = drag ?? _fractionOf(_position);
    _elapsedSeconds.value = shown.inSeconds;
  }

  double _fractionOf(Duration position) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double _fractionAt(Offset localPosition, double width) =>
      width <= 0 ? 0 : (localPosition.dx / width).clamp(0.0, 1.0);

  void _seekTo(double fraction) {
    final target = widget.duration * fraction;
    context.read<PlaybackBloc>().add(PlaybackSeek(target));
  }

  void _drag(double? fraction) {
    _dragFraction = fraction;
    _update();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeStyle = theme.textTheme.labelLarge?.copyWith(
      color: colorScheme.onSecondaryFixed,
      fontSize: 16,
    );
    final canSeek = widget.hasSong && widget.duration > Duration.zero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              key: const ValueKey('landing_progress_bar'),
              behavior: HitTestBehavior.opaque,
              onTapUp: canSeek
                  ? (d) => _seekTo(_fractionAt(d.localPosition, width))
                  : null,
              onHorizontalDragUpdate: canSeek
                  ? (d) => _drag(_fractionAt(d.localPosition, width))
                  : null,
              onHorizontalDragEnd: canSeek
                  ? (_) {
                      final target = _dragFraction;
                      _drag(null);
                      if (target != null) _seekTo(target);
                    }
                  : null,
              // Ticks repaint only the bar, not the rest of the screen.
              child: RepaintBoundary(
                child: SizedBox(
                  height: 24,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _fraction,
                    builder: (_, fraction, _) => CustomPaint(
                      painter: _ProgressPainter(
                        fraction: fraction,
                        activeColor: colorScheme.primary,
                        trackColor: colorScheme.secondaryContainer,
                        endDotColor: widget.hasSong
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _elapsedSeconds,
              builder: (_, seconds, _) => Text(
                formatDuration(Duration(seconds: seconds)),
                style: timeStyle,
              ),
            ),
            Text(formatDuration(widget.duration), style: timeStyle),
          ],
        ),
      ],
    );
  }
}

/// Elapsed segment, a small gap, the remaining track and an end dot.
class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.fraction,
    required this.activeColor,
    required this.trackColor,
    required this.endDotColor,
  });

  final double fraction;
  final Color activeColor;
  final Color trackColor;
  final Color endDotColor;

  static const _height = 4.0;
  static const _gap = 6.0;
  static const _dot = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final radius = const Radius.circular(_height / 2);
    final elapsedEnd = size.width * fraction;

    if (elapsedEnd > 0) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          0,
          y - _height / 2,
          elapsedEnd,
          y + _height / 2,
          radius,
        ),
        Paint()..color = activeColor,
      );
    }

    final trackStart = elapsedEnd > 0 ? elapsedEnd + _gap : 0.0;
    if (trackStart < size.width) {
      canvas.drawRRect(
        RRect.fromLTRBR(
          trackStart,
          y - _height / 2,
          size.width,
          y + _height / 2,
          radius,
        ),
        Paint()..color = trackColor,
      );
    }

    canvas.drawCircle(
      Offset(size.width - _dot / 2, y),
      _dot / 2,
      Paint()..color = endDotColor,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.fraction != fraction ||
      old.activeColor != activeColor ||
      old.trackColor != trackColor ||
      old.endDotColor != endDotColor;
}
