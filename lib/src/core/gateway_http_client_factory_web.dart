import 'dart:js_interop';

import 'package:web/web.dart' as web;

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
    final web.Headers requestHeaders = web.Headers();
    headers.forEach(requestHeaders.set);

    final web.Response response = await web.window.fetch(
      uri.toString().toJS,
      web.RequestInit(
        method: method,
        headers: requestHeaders,
        body: body?.toJS,
      ),
    ).toDart;

    final String responseBody = (await response.text().toDart).toDart;

    return GatewayHttpResponse(
      statusCode: response.status,
      body: responseBody,
    );
  }
}
