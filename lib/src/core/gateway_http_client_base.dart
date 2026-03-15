class GatewayHttpResponse {
  const GatewayHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

abstract class GatewayHttpClient {
  Future<GatewayHttpResponse> send(
    Uri uri, {
    required String method,
    Map<String, String> headers = const <String, String>{},
    String? body,
  });
}
