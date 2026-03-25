// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

import 'gateway_http_client_base.dart';

GatewayHttpClient createGatewayHttpClient() {
  return _WebGatewayHttpClient();
}

class _WebGatewayHttpClient implements GatewayHttpClient {
  @override
  Future<GatewayHttpResponse> send(
    Uri uri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    final html.HttpRequest response = await html.HttpRequest.request(
      uri.toString(),
      method: method,
      requestHeaders: headers,
      sendData: body,
    );
    return GatewayHttpResponse(
      statusCode: response.status ?? 0,
      body: response.responseText ?? '',
    );
  }
}
