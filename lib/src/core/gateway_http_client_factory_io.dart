import 'dart:convert';
import 'dart:io';

import 'gateway_http_client_base.dart';

GatewayHttpClient createGatewayHttpClient() {
  return _IoGatewayHttpClient();
}

class _IoGatewayHttpClient implements GatewayHttpClient {
  final HttpClient _client = HttpClient();

  @override
  Future<GatewayHttpResponse> send(
    Uri uri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    final HttpClientRequest request = await _client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.write(body);
    }
    final HttpClientResponse response = await request.close();
    return GatewayHttpResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
    );
  }
}
