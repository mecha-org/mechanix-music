import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/mpris/bridge/mechanix_application_control.dart';
import 'package:mechanix_music/features/mpris/bridge/playback_mpris_bridge.dart';
import 'package:mechanix_music/features/mpris/data/server/dbus_mpris_server.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';

/// Starts MPRIS when the app starts and stops it when the app closes.
///
/// Wraps `MusicApp` in main.dart, under the `MultiBlocProvider`, so it can
/// read `PlaybackBloc` and `PlaybackRepository` from context.
///
/// Lifecycle:
///  * initState: build `DBusMprisServer` + `PlaybackMprisBridge`,
///    `server.start()`, then `bridge.attach(server)`.
///    If the session bus is unreachable, log and carry on: the app must
///    work without MPRIS.
///  * dispose: `bridge.detach()`, then `server.dispose()`.
///
/// Note: `PlaybackBloc` is lazy in main.dart; reading it here creates it at
/// startup, which MPRIS needs anyway (clients must see the player).
class MprisScope extends StatefulWidget {
  const MprisScope({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Off in tests and on non-Linux targets.
  final bool enabled;

  @override
  State<MprisScope> createState() => _MprisScopeState();
}

class _MprisScopeState extends State<MprisScope> {
  PlaybackMprisBridge? _bridge;
  DBusMprisServer? _server;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) unawaited(_start());
  }

  Future<void> _start() async {
    // Read synchronously, before the first await.
    final bridge = PlaybackMprisBridge(
      playbackBloc: context.read<PlaybackBloc>(),
      playbackRepository: context.read<PlaybackRepository>(),
    );
    final server = DBusMprisServer(
      player: bridge,
      application: MechanixApplicationControl(),
    );

    try {
      await server.start();
    } catch (e) {
      AppLogger.e('[MprisScope] MPRIS unavailable, continuing without it: $e');
      await server.dispose();
      return;
    }

    if (!mounted) {
      await server.dispose();
      return;
    }
    bridge.attach(server);
    _bridge = bridge;
    _server = server;
    AppLogger.i('[MprisScope] MPRIS player registered as ${server.busName}');
  }

  @override
  void dispose() {
    final bridge = _bridge;
    final server = _server;
    _bridge = null;
    _server = null;
    unawaited(() async {
      await bridge?.detach();
      await server?.dispose();
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
