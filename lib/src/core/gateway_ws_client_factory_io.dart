import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'gateway_ws_client_base.dart';

GatewayWsClient createGatewayWsClient() {
  return _IoGatewayWsClient();
}

class _IoGatewayWsClient implements GatewayWsClient {
  @override
  Future<GatewayWsResponse> request(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
    required String method,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final _ManagedGatewaySocket connection = await _ManagedGatewaySocket.open(
      uri,
    );
    try {
      final GatewayWsConnectContext connectResult = await connection
          .connect(buildConnect)
          .timeout(const Duration(seconds: 10));
      if (connectResult.errorCode != null) {
        return GatewayWsResponse(
          ok: false,
          errorCode: connectResult.errorCode,
          errorMessage: connectResult.errorMessage,
          errorDetails: connectResult.errorDetails,
        );
      }
      final GatewayWsResponse response = await connection
          .sendRequest(method, params)
          .timeout(const Duration(seconds: 15));
      if (!response.ok || connectResult.payload.isEmpty) {
        return response;
      }
      final Map<String, dynamic> mergedPayload = <String, dynamic>{
        ...response.payload,
        if (!response.payload.containsKey('auth') &&
            connectResult.payload.containsKey('auth'))
          'auth': connectResult.payload['auth'],
        if (!response.payload.containsKey('server') &&
            connectResult.payload.containsKey('server'))
          'server': connectResult.payload['server'],
        if (!response.payload.containsKey('snapshot') &&
            connectResult.payload.containsKey('snapshot'))
          'snapshot': connectResult.payload['snapshot'],
      };
      return GatewayWsResponse(ok: true, payload: mergedPayload);
    } finally {
      await connection.close();
    }
  }

  @override
  Future<GatewayWsConnectContext> connect(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
  }) async {
    final _ManagedGatewaySocket connection = await _ManagedGatewaySocket.open(
      uri,
    );
    try {
      return await connection
          .connect(buildConnect)
          .timeout(const Duration(seconds: 10));
    } finally {
      await connection.close();
    }
  }
}

class _ManagedGatewaySocket {
  _ManagedGatewaySocket._(this._socket);

  final WebSocket _socket;
  final Map<String, Completer<GatewayWsResponse>> _pending =
      <String, Completer<GatewayWsResponse>>{};
  final Completer<GatewayWsChallenge> _challenge = Completer<GatewayWsChallenge>();
  int _counter = 0;
  late final StreamSubscription<dynamic> _subscription;
  bool _closed = false;
  bool _closing = false;

  static Future<_ManagedGatewaySocket> open(Uri uri) async {
    final WebSocket socket = await WebSocket.connect(uri.toString());
    socket.done.catchError((Object _) {
      // Some Android TLS shutdown paths complete `done` with a socket error
      // after the stream has already been closed. Treat that as expected.
    });
    final _ManagedGatewaySocket connection = _ManagedGatewaySocket._(socket);
    connection._subscription = socket.listen(
      connection._handleMessage,
      onError: connection._handleStreamFailure,
      onDone: connection._handleDone,
      cancelOnError: false,
    );
    return connection;
  }

  Future<GatewayWsConnectContext> connect(
    Future<Map<String, dynamic>> Function(GatewayWsChallenge challenge)
    buildConnect,
  ) async {
    final GatewayWsChallenge challenge = await _challenge.future.timeout(
      const Duration(milliseconds: 900),
      onTimeout: () => const GatewayWsChallenge(),
    );
    final Map<String, dynamic> connectPayload = await buildConnect(challenge);
    final GatewayWsResponse response = await sendRequest(
      'connect',
      connectPayload,
      id: 'req-connect',
    );
    return GatewayWsConnectContext(
      payload: response.payload,
      challenge: challenge,
      errorCode: response.errorCode,
      errorMessage: response.errorMessage,
      errorDetails: response.errorDetails,
    );
  }

  Future<GatewayWsResponse> sendRequest(
    String method,
    Map<String, dynamic> params, {
    String? id,
  }) {
    final String requestId = id ?? 'req-${++_counter}';
    final Completer<GatewayWsResponse> completer =
        Completer<GatewayWsResponse>();
    _pending[requestId] = completer;
    _socket.add(
      jsonEncode(<String, dynamic>{
        'type': 'req',
        'id': requestId,
        'method': method,
        'params': params,
      }),
    );
    return completer.future;
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closing = true;
    _closed = true;
    await _subscription.cancel();
    try {
      await _socket.close();
    } on SocketException {
      // Android occasionally reports a closed TLS socket while the peer is
      // already shutting down. Treat that as a normal close path.
    }
    try {
      await _socket.done;
    } on SocketException {
      // Swallow late TLS shutdown noise from dart:io after close().
    }
  }

  void _handleMessage(dynamic event) {
    final Map<String, dynamic> message =
        jsonDecode(event as String) as Map<String, dynamic>;
    final String type = message['type'] as String? ?? '';
    if (type == 'event') {
      if ((message['event'] as String? ?? '') == 'connect.challenge' &&
          !_challenge.isCompleted) {
        final Map<String, dynamic> payload =
            message['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
        _challenge.complete(
          GatewayWsChallenge(
            nonce: payload['nonce'] as String?,
            timestampMs: _readInt(payload['ts']) ?? _readInt(payload['tsMs']),
          ),
        );
      }
      return;
    }
    if (type != 'res') {
      return;
    }

    final String requestId = message['id'] as String? ?? '';
    final Completer<GatewayWsResponse>? completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) {
      return;
    }

    final bool ok = message['ok'] as bool? ?? false;
    if (ok) {
      completer.complete(
        GatewayWsResponse(
          ok: true,
          payload:
              message['payload'] as Map<String, dynamic>? ??
              <String, dynamic>{},
        ),
      );
      return;
    }

    final Map<String, dynamic> error =
        message['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final Map<String, dynamic>? details =
        error['details'] as Map<String, dynamic>?;
    completer.complete(
      GatewayWsResponse(
        ok: false,
        errorCode: details?['code'] as String? ?? error['code'] as String?,
        errorMessage: error['message'] as String?,
        errorDetails: details,
      ),
    );
  }

  void _handleDone() {
    if (_closing || _closed) {
      if (!_challenge.isCompleted) {
        _challenge.complete(const GatewayWsChallenge());
      }
      _pending.clear();
      return;
    }
    if (!_challenge.isCompleted) {
      _challenge.complete(const GatewayWsChallenge());
    }
    _handleStreamFailure(
      StateError('Gateway socket closed before the request completed.'),
    );
  }

  void _handleStreamFailure(Object error) {
    if (_closing || _closed) {
      if (!_challenge.isCompleted) {
        _challenge.complete(const GatewayWsChallenge());
      }
      _pending.clear();
      return;
    }
    if (!_challenge.isCompleted) {
      _challenge.completeError(error);
    }
    for (final Completer<GatewayWsResponse> completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
  }
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
