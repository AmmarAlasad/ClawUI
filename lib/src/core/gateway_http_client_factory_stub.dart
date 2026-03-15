import 'gateway_http_client_base.dart';

GatewayHttpClient createGatewayHttpClient() {
  return _UnsupportedGatewayHttpClient();
}

class _UnsupportedGatewayHttpClient implements GatewayHttpClient {
  @override
  Future<GatewayHttpResponse> send(
    Uri uri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) {
    throw UnsupportedError('HTTP client is unavailable on this platform.');
  }
}
