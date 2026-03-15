import 'dart:convert';
import 'dart:io';

import 'gateway_http_client_base.dart';

GatewayHttpClient createGatewayHttpClient() {
  return _IoGatewayHttpClient();
}

class _IoGatewayHttpClient implements GatewayHttpClient {
  _IoGatewayHttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  final HttpClient _client = HttpClient();

  @override
  Future<GatewayHttpResponse> send(
    Uri uri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    final HttpClientRequest request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 8));
    headers.forEach(request.headers.set);
    if (body != null) {
      request.write(body);
    }
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 12),
    );
    return GatewayHttpResponse(
      statusCode: response.statusCode,
      body: await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 12)),
    );
  }
}
