import 'gateway_ws_client_base.dart';

/// Stub implementation for platforms that don't support dart:io WebSocket.
class GatewayLiveSession {
  const GatewayLiveSession._();

  static Future<GatewayLiveSession> open(
    Uri uri,
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) =>
      Future.error(UnsupportedError('GatewayLiveSession not supported on this platform'));

  Future<GatewayWsResponse> rpc(String method, Map<String, dynamic> params) =>
      Future.error(UnsupportedError('GatewayLiveSession not supported on this platform'));

  Stream<Map<String, dynamic>> get events => const Stream.empty();

  Future<void> close() async {}

  bool get isConnected => false;
}

class GatewaySessionPool {
  static final GatewaySessionPool instance = GatewaySessionPool._();
  GatewaySessionPool._();

  bool get isSupported => false;

  Future<GatewayLiveSession> acquire(
    String key,
    Uri uri,
    Future<Map<String, dynamic>> Function(GatewayWsChallenge) buildConnect,
  ) =>
      Future.error(UnsupportedError('GatewaySessionPool not supported on this platform'));

  GatewayLiveSession? getActive(String key) => null;

  void invalidate(String key) {}
}
