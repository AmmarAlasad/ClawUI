import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gateway_ws_client_base.dart';

/// A persistent, multiplexed WebSocket session to an OpenClaw gateway.
///
/// One session = one WebSocket connection kept alive for the lifetime of the
/// connection profile. Multiple concurrent RPC calls are multiplexed over
/// the same connection. Server-pushed events (e.g. `chat.stream`) are
/// delivered via the [events] broadcast stream.
class GatewayLiveSession {
  GatewayLiveSession._({required Uri uri}) : _uri = uri;

  final Uri _uri;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  final Map<String, Completer<GatewayWsResponse>> _pending = <String, Completer<GatewayWsResponse>>{};
  Completer<GatewayWsChallenge>? _challengeCompleter;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();
  int _seq = 0;
  bool _connected = false;
  bool _closed = false;

  bool get isConnected => _connected && !_closed;
  Stream<Map<String, dynamic>> get events => _events.stream;

  static Future<GatewayLiveSession> open(
    Uri uri,
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) async {
    final GatewayLiveSession session = GatewayLiveSession._(uri: uri);
    await session._init(buildConnect);
    return session;
  }

  Future<void> _init(
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) async {
    _challengeCompleter = Completer<GatewayWsChallenge>();
    final WebSocket socket = await WebSocket.connect(_uri.toString())
        .timeout(const Duration(seconds: 10));
    socket.done.catchError((_) {});
    _socket = socket;
    _sub = socket.listen(
      _onMessage,
      onDone: _onDisconnect,
      onError: (_) => _onDisconnect(),
      cancelOnError: false,
    );

    final GatewayWsChallenge challenge = await _challengeCompleter!.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => const GatewayWsChallenge(),
    );
    final Map<String, dynamic> connectPayload = await buildConnect(challenge);
    final GatewayWsResponse connectResp = await _sendReq(
      'connect',
      connectPayload,
      id: 'req-connect',
    ).timeout(const Duration(seconds: 12));

    if (!connectResp.ok) {
      await close();
      throw Exception(connectResp.errorMessage ?? 'WS connect handshake failed');
    }
    _connected = true;
  }

  /// Send an RPC request and await the response.
  Future<GatewayWsResponse> rpc(String method, Map<String, dynamic> params) {
    if (!isConnected) {
      return Future<GatewayWsResponse>.error(StateError('Session is not connected'));
    }
    return _sendReq(method, params).timeout(const Duration(seconds: 30));
  }

  Future<GatewayWsResponse> _sendReq(
    String method,
    Map<String, dynamic> params, {
    String? id,
  }) {
    final String reqId = id ?? 'req-${++_seq}';
    final Completer<GatewayWsResponse> c = Completer<GatewayWsResponse>();
    _pending[reqId] = c;
    _socket!.add(jsonEncode(<String, dynamic>{
      'type': 'req',
      'id': reqId,
      'method': method,
      'params': params,
    }));
    return c.future;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _connected = false;
    if (!(_challengeCompleter?.isCompleted ?? true)) {
      _challengeCompleter?.complete(const GatewayWsChallenge());
    }
    await _sub?.cancel();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    _failPending(StateError('Session closed'));
    if (!_events.isClosed) _events.close();
  }

  void _onMessage(dynamic data) {
    try {
      final Map<String, dynamic> msg =
          jsonDecode(data as String) as Map<String, dynamic>;
      final String type = msg['type'] as String? ?? '';

      if (type == 'event') {
        final String evt = msg['event'] as String? ?? '';
        if (evt == 'connect.challenge') {
          final Map<String, dynamic> pl =
              msg['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
          if (!(_challengeCompleter?.isCompleted ?? true)) {
            _challengeCompleter?.complete(GatewayWsChallenge(
              nonce: pl['nonce'] as String?,
              timestampMs: _parseInt(pl['ts']) ?? _parseInt(pl['tsMs']),
            ));
          }
        }
        if (!_events.isClosed) _events.add(msg);
        return;
      }

      if (type == 'res') {
        final String reqId = msg['id'] as String? ?? '';
        final Completer<GatewayWsResponse>? c = _pending.remove(reqId);
        if (c == null || c.isCompleted) return;
        final bool ok = msg['ok'] as bool? ?? false;
        if (ok) {
          c.complete(GatewayWsResponse(
            ok: true,
            payload: msg['payload'] as Map<String, dynamic>? ?? <String, dynamic>{},
          ));
        } else {
          final Map<String, dynamic> err =
              msg['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
          final Map<String, dynamic>? details = err['details'] as Map<String, dynamic>?;
          c.complete(GatewayWsResponse(
            ok: false,
            errorCode: details?['code'] as String? ?? err['code'] as String?,
            errorMessage: err['message'] as String?,
            errorDetails: details,
          ));
        }
      }
    } catch (_) {}
  }

  void _onDisconnect() {
    if (!(_challengeCompleter?.isCompleted ?? true)) {
      _challengeCompleter?.complete(const GatewayWsChallenge());
    }
    _connected = false;
    _failPending(StateError('WebSocket disconnected'));
    if (!_events.isClosed) _events.close();
  }

  void _failPending(Object err) {
    final Map<String, Completer<GatewayWsResponse>> toFail = Map.of(_pending);
    _pending.clear();
    for (final Completer<GatewayWsResponse> c in toFail.values) {
      if (!c.isCompleted) c.completeError(err);
    }
  }

  static int? _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }
}

/// Singleton pool that keeps one [GatewayLiveSession] alive per gateway endpoint.
/// Concurrent callers asking for the same key wait for the single in-progress
/// open rather than creating duplicate connections.
class GatewaySessionPool {
  static final GatewaySessionPool instance = GatewaySessionPool._();
  GatewaySessionPool._();

  bool get isSupported => true;

  final Map<String, GatewayLiveSession> _active = <String, GatewayLiveSession>{};
  final Map<String, Future<GatewayLiveSession>> _opening =
      <String, Future<GatewayLiveSession>>{};

  /// Returns an open session for [key], opening one if needed.
  Future<GatewayLiveSession> acquire(
    String key,
    Uri uri,
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) {
    final GatewayLiveSession? existing = _active[key];
    if (existing != null && existing.isConnected) return Future.value(existing);
    _active.remove(key);

    final Future<GatewayLiveSession>? pending = _opening[key];
    if (pending != null) return pending;

    final Future<GatewayLiveSession> future = _open(key, uri, buildConnect);
    _opening[key] = future;
    return future;
  }

  Future<GatewayLiveSession> _open(
    String key,
    Uri uri,
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) async {
    try {
      final GatewayLiveSession session = await GatewayLiveSession.open(uri, buildConnect);
      _active[key] = session;
      return session;
    } finally {
      _opening.remove(key);
    }
  }

  /// Returns the currently-active session without opening a new one.
  GatewayLiveSession? getActive(String key) {
    final GatewayLiveSession? s = _active[key];
    if (s == null || !s.isConnected) {
      _active.remove(key);
      return null;
    }
    return s;
  }

  void invalidate(String key) {
    _active.remove(key)?.close();
  }
}
