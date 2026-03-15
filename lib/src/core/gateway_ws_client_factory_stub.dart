import 'gateway_ws_client_base.dart';

GatewayWsClient createGatewayWsClient() {
  return _UnsupportedGatewayWsClient();
}

class _UnsupportedGatewayWsClient implements GatewayWsClient {
  @override
  Future<GatewayWsResponse> request(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
    required String method,
    Map<String, dynamic> params = const <String, dynamic>{},
  }) {
    throw UnsupportedError('WebSocket client is unavailable on this platform.');
  }

  @override
  Future<GatewayWsConnectContext> connect(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
  }) {
    throw UnsupportedError('WebSocket client is unavailable on this platform.');
  }
}
