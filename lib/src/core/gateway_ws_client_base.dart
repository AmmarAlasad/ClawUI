class GatewayWsResponse {
  const GatewayWsResponse({
    required this.ok,
    this.payload = const <String, dynamic>{},
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });

  final bool ok;
  final Map<String, dynamic> payload;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;
}

class GatewayWsConnectContext {
  const GatewayWsConnectContext({
    this.payload = const <String, dynamic>{},
    this.challenge = const GatewayWsChallenge(),
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });

  final Map<String, dynamic> payload;
  final GatewayWsChallenge challenge;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? errorDetails;
}

class GatewayWsChallenge {
  const GatewayWsChallenge({this.nonce, this.timestampMs});

  final String? nonce;
  final int? timestampMs;
}

abstract class GatewayWsClient {
  Future<GatewayWsResponse> request(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
    required String method,
    Map<String, dynamic> params = const <String, dynamic>{},
  });

  Future<GatewayWsConnectContext> connect(
    Uri uri, {
    required Future<Map<String, dynamic>> Function(
      GatewayWsChallenge challenge,
    )
    buildConnect,
  });
}
