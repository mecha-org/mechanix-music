import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:mechanix_music/core/utils/app_logger.dart';
import 'package:mechanix_music/features/mpris/data/models/mpris_player_state.dart';
import 'package:mechanix_music/features/mpris/data/mpris_controls.dart';
import 'package:mechanix_music/features/mpris/data/server/mpris_server.dart';

/// [MprisServer] over the `dbus` package.
///
/// Exposes:
///  * `org.mpris.MediaPlayer2`: Identity, DesktopEntry, CanRaise, CanQuit,
///    HasTrackList = false, SupportedUriSchemes = [], SupportedMimeTypes = [];
///    Raise, Quit.
///  * `org.mpris.MediaPlayer2.Player`: PlaybackStatus, Metadata, Position,
///    Volume (fixed 1.0), Rate/MinimumRate/MaximumRate (fixed 1.0),
///    CanGoNext, CanGoPrevious, CanPlay, CanPause, CanSeek, CanControl = true;
///    Play, Pause, PlayPause, Stop, Next, Previous, Seek, SetPosition,
///    OpenUri (unsupported: returns an error); signal Seeked.
///
/// Not exposed (optional in the spec): Shuffle, LoopStatus, TrackList,
/// Playlists. All properties are read-only for clients.
class DBusMprisServer implements MprisServer {
  DBusMprisServer({
    required MprisPlayerControl player,
    required MprisApplicationControl application,
    this.playerName = 'mechanix_music',
    this.identity = 'Mechanix Music',
    this.desktopEntry = 'org.mechanix.music',
    this.trackPathPrefix = '/org/mechanix/music/track',
    DBusClient? client,
  }) : _player = player,
       _application = application,
       _client = client,
       _ownsClient = client == null;

  static const rootInterface = 'org.mpris.MediaPlayer2';
  static const playerInterface = 'org.mpris.MediaPlayer2.Player';
  static const objectPath = '/org/mpris/MediaPlayer2';
  static const noTrackPath = '/org/mpris/MediaPlayer2/TrackList/NoTrack';

  /// Bus name suffix: `org.mpris.MediaPlayer2.<playerName>`.
  final String playerName;

  /// `Identity`. Matches `Name=` in org.mechanix.music.desktop.
  final String identity;

  /// `DesktopEntry`. The .desktop file name without the extension.
  final String desktopEntry;

  /// Prefix for `mpris:trackid` object paths. Must not be under /org/mpris.
  final String trackPathPrefix;

  final MprisPlayerControl _player;
  final MprisApplicationControl _application;
  DBusClient? _client;
  final bool _ownsClient;

  _MprisObject? _object;
  String? _busName;

  MprisPlayerState _state = const MprisPlayerState();

  /// Player properties as last sent to clients (Position excluded: clients
  /// poll it and it must not be in PropertiesChanged).
  Map<String, DBusValue> _publishedPlayerProperties = const {};

  @override
  String? get busName => _busName;

  @override
  bool get isRunning => _busName != null;

  @override
  Future<void> start() async {
    if (isRunning) return;
    final client = _client ??= DBusClient.session();
    final object = _MprisObject(this);
    try {
      // Register first, so the object is there as soon as the name appears.
      await client.registerObject(object);
      _object = object;
      _publishedPlayerProperties = playerProperties();
      _busName = await _requestName(client);
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  /// Owns `org.mpris.MediaPlayer2.<playerName>`, or
  /// `….instance<pid>` when another instance already owns it.
  Future<String> _requestName(DBusClient client) async {
    final base = 'org.mpris.MediaPlayer2.$playerName';
    for (final name in [base, '$base.instance$pid']) {
      final reply = await client.requestName(
        name,
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply == DBusRequestNameReply.primaryOwner ||
          reply == DBusRequestNameReply.alreadyOwner) {
        return name;
      }
    }
    throw StateError('Could not own an MPRIS bus name for $base');
  }

  @override
  void publish(MprisPlayerState state) {
    _state = state;
    final object = _object;
    if (object == null || !isRunning) return;

    final properties = playerProperties();
    final changed = <String, DBusValue>{
      for (final entry in properties.entries)
        if (_publishedPlayerProperties[entry.key] != entry.value)
          entry.key: entry.value,
    };
    _publishedPlayerProperties = properties;
    if (changed.isEmpty) return;

    unawaited(
      object
          .emitPropertiesChanged(playerInterface, changedProperties: changed)
          .catchError(
            (Object e) => AppLogger.e('[MPRIS] PropertiesChanged failed: $e'),
          ),
    );
  }

  @override
  void notifySeeked(Duration position) {
    final object = _object;
    if (object == null || !isRunning) return;
    unawaited(
      object
          .emitSignal(playerInterface, 'Seeked', [
            DBusInt64(position.inMicroseconds),
          ])
          .catchError((Object e) => AppLogger.e('[MPRIS] Seeked failed: $e')),
    );
  }

  @override
  Future<void> dispose() => _release();

  Future<void> _release() async {
    final client = _client;
    final name = _busName;
    final object = _object;
    _busName = null;
    _object = null;
    if (client == null) return;
    try {
      if (name != null) await client.releaseName(name);
      if (object != null) await client.unregisterObject(object);
    } catch (e) {
      AppLogger.e('[MPRIS] Error while releasing the bus name: $e');
    }
    if (_ownsClient) {
      _client = null;
      await client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  @visibleForTesting
  Map<String, DBusValue> rootProperties() => {
    'Identity': DBusString(identity),
    'DesktopEntry': DBusString(desktopEntry),
    'CanRaise': DBusBoolean(_application.canRaise),
    'CanQuit': DBusBoolean(_application.canQuit),
    'HasTrackList': const DBusBoolean(false),
    'SupportedUriSchemes': DBusArray.string(const []),
    'SupportedMimeTypes': DBusArray.string(const []),
  };

  /// Every player property except Position.
  @visibleForTesting
  Map<String, DBusValue> playerProperties() => {
    'PlaybackStatus': DBusString(switch (_state.status) {
      MprisPlaybackStatus.playing => 'Playing',
      MprisPlaybackStatus.paused => 'Paused',
      MprisPlaybackStatus.stopped => 'Stopped',
    }),
    'Metadata': DBusDict.stringVariant(metadata(_state.track)),
    'Volume': const DBusDouble(1.0),
    'Rate': const DBusDouble(1.0),
    'MinimumRate': const DBusDouble(1.0),
    'MaximumRate': const DBusDouble(1.0),
    'CanGoNext': DBusBoolean(_state.canGoNext),
    'CanGoPrevious': DBusBoolean(_state.canGoPrevious),
    // Play also starts the queue when nothing is loaded.
    'CanPlay': const DBusBoolean(true),
    'CanPause': DBusBoolean(_state.track != null),
    'CanSeek': DBusBoolean(_state.canSeek),
    'CanControl': const DBusBoolean(true),
  };

  DBusValue _position() => DBusInt64(_player.position.inMicroseconds);

  /// The `Metadata` dictionary for [track].
  @visibleForTesting
  Map<String, DBusValue> metadata(MprisTrack? track) {
    if (track == null) {
      return {'mpris:trackid': DBusObjectPath(noTrackPath)};
    }
    final album = track.album;
    final length = track.length;
    final artUrl = track.artUrl;
    final url = track.url;
    return {
      'mpris:trackid': DBusObjectPath(trackPath(track.id)),
      'xesam:title': DBusString(track.title),
      if (track.artists.isNotEmpty)
        'xesam:artist': DBusArray.string(track.artists),
      if (album != null) 'xesam:album': DBusString(album),
      if (length != null) 'mpris:length': DBusInt64(length.inMicroseconds),
      if (artUrl != null) 'mpris:artUrl': DBusString(artUrl.toString()),
      if (url != null) 'xesam:url': DBusString(url.toString()),
    };
  }

  /// `mpris:trackid` for a track id. Object path elements may only contain
  /// `[A-Za-z0-9_]`, so other bytes (and `_` itself) are written as `_xx`.
  @visibleForTesting
  String trackPath(String id) {
    final encoded = StringBuffer();
    for (final byte in utf8.encode(id)) {
      final isAlphanumeric =
          (byte >= 0x30 && byte <= 0x39) ||
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A);
      if (isAlphanumeric) {
        encoded.writeCharCode(byte);
      } else {
        encoded.write('_${byte.toRadixString(16).padLeft(2, '0')}');
      }
    }
    return '$trackPathPrefix/${encoded.isEmpty ? '_' : encoded}';
  }

  Future<DBusMethodResponse> _getProperty(
    String interface,
    String name,
  ) async {
    final value = switch (interface) {
      rootInterface => rootProperties()[name],
      playerInterface =>
        name == 'Position' ? _position() : playerProperties()[name],
      _ => null,
    };
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }

  Future<DBusMethodResponse> _getAllProperties(String interface) async {
    return switch (interface) {
      rootInterface => DBusGetAllPropertiesResponse(rootProperties()),
      playerInterface => DBusGetAllPropertiesResponse({
        ...playerProperties(),
        'Position': _position(),
      }),
      _ => DBusMethodErrorResponse.unknownInterface(),
    };
  }

  Future<DBusMethodResponse> _setProperty(
    String interface,
    String name,
  ) async {
    final known = switch (interface) {
      rootInterface => rootProperties().containsKey(name),
      playerInterface =>
        name == 'Position' || playerProperties().containsKey(name),
      _ => false,
    };
    return known
        ? DBusMethodErrorResponse.propertyReadOnly()
        : DBusMethodErrorResponse.unknownProperty();
  }

  // ---------------------------------------------------------------------------
  // Methods
  // ---------------------------------------------------------------------------

  Future<DBusMethodResponse> _handleMethodCall(DBusMethodCall call) async {
    try {
      return switch (call.interface) {
        rootInterface => await _handleRootCall(call),
        playerInterface => await _handlePlayerCall(call),
        _ => DBusMethodErrorResponse.unknownInterface(),
      };
    } catch (e) {
      AppLogger.e('[MPRIS] ${call.interface}.${call.name} failed: $e');
      return DBusMethodErrorResponse.failed('$e');
    }
  }

  Future<DBusMethodResponse> _handleRootCall(DBusMethodCall call) async {
    if (call.values.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
    switch (call.name) {
      case 'Raise':
        if (_application.canRaise) await _application.raise();
      case 'Quit':
        if (_application.canQuit) await _application.quit();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  Future<DBusMethodResponse> _handlePlayerCall(DBusMethodCall call) async {
    final Future<void> Function()? simple = switch (call.name) {
      'Play' => _player.play,
      'Pause' => _player.pause,
      'PlayPause' => _player.playPause,
      'Stop' => _player.stop,
      'Next' => _player.next,
      'Previous' => _player.previous,
      _ => null,
    };
    if (simple != null) {
      if (call.values.isNotEmpty) return DBusMethodErrorResponse.invalidArgs();
      await simple();
      return DBusMethodSuccessResponse();
    }

    switch (call.name) {
      case 'Seek':
        if (call.signature != DBusSignature('x')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        await _seekBy(Duration(microseconds: call.values[0].asInt64()));
      case 'SetPosition':
        if (call.signature != DBusSignature('ox')) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        await _setPosition(
          call.values[0].asObjectPath().value,
          Duration(microseconds: call.values[1].asInt64()),
        );
      case 'OpenUri':
        return DBusMethodErrorResponse.notSupported(
          'OpenUri is not supported',
        );
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  /// `Seek(Offset)`: relative. Before the start → 0; past the end → Next.
  Future<void> _seekBy(Duration offset) async {
    if (!_state.canSeek) return;
    var target = _player.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    final length = _state.track?.length;
    if (length != null && target > length) {
      if (_state.canGoNext) await _player.next();
      return;
    }
    await _player.seekTo(target);
  }

  /// `SetPosition(TrackId, Position)`: ignored for a stale track id or a
  /// position outside the track, as the spec requires.
  Future<void> _setPosition(String trackId, Duration position) async {
    final track = _state.track;
    if (!_state.canSeek || track == null) return;
    if (trackId != trackPath(track.id)) return;
    final length = track.length;
    if (position < Duration.zero || (length != null && position > length)) {
      return;
    }
    await _player.seekTo(position);
  }

  // ---------------------------------------------------------------------------
  // Introspection
  // ---------------------------------------------------------------------------

  List<DBusIntrospectInterface> _introspect() {
    DBusIntrospectProperty readOnly(String name, String type) =>
        DBusIntrospectProperty(
          name,
          DBusSignature(type),
          access: DBusPropertyAccess.read,
        );
    DBusIntrospectArgument inArg(String type, String name) =>
        DBusIntrospectArgument(
          DBusSignature(type),
          DBusArgumentDirection.in_,
          name: name,
        );

    return [
      DBusIntrospectInterface(
        rootInterface,
        methods: [DBusIntrospectMethod('Raise'), DBusIntrospectMethod('Quit')],
        properties: [
          readOnly('Identity', 's'),
          readOnly('DesktopEntry', 's'),
          readOnly('CanRaise', 'b'),
          readOnly('CanQuit', 'b'),
          readOnly('HasTrackList', 'b'),
          readOnly('SupportedUriSchemes', 'as'),
          readOnly('SupportedMimeTypes', 'as'),
        ],
      ),
      DBusIntrospectInterface(
        playerInterface,
        methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod('Seek', args: [inArg('x', 'Offset')]),
          DBusIntrospectMethod(
            'SetPosition',
            args: [inArg('o', 'TrackId'), inArg('x', 'Position')],
          ),
          DBusIntrospectMethod('OpenUri', args: [inArg('s', 'Uri')]),
        ],
        signals: [
          DBusIntrospectSignal(
            'Seeked',
            args: [
              DBusIntrospectArgument(
                DBusSignature('x'),
                DBusArgumentDirection.out,
                name: 'Position',
              ),
            ],
          ),
        ],
        properties: [
          readOnly('PlaybackStatus', 's'),
          readOnly('Rate', 'd'),
          readOnly('Metadata', 'a{sv}'),
          readOnly('Volume', 'd'),
          readOnly('Position', 'x'),
          readOnly('MinimumRate', 'd'),
          readOnly('MaximumRate', 'd'),
          readOnly('CanGoNext', 'b'),
          readOnly('CanGoPrevious', 'b'),
          readOnly('CanPlay', 'b'),
          readOnly('CanPause', 'b'),
          readOnly('CanSeek', 'b'),
          readOnly('CanControl', 'b'),
        ],
      ),
    ];
  }
}

/// The exported `/org/mpris/MediaPlayer2` object; forwards to the server.
class _MprisObject extends DBusObject {
  _MprisObject(this._server)
    : super(DBusObjectPath(DBusMprisServer.objectPath));

  final DBusMprisServer _server;

  @override
  List<DBusIntrospectInterface> introspect() => _server._introspect();

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) =>
      _server._handleMethodCall(methodCall);

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) =>
      _server._getProperty(interface, name);

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) =>
      _server._getAllProperties(interface);

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) => _server._setProperty(interface, name);
}
