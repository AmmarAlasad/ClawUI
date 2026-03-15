import 'gateway_http_client_base.dart';
import 'gateway_http_client_factory_stub.dart'
    if (dart.library.io) 'gateway_http_client_factory_io.dart'
    if (dart.library.html) 'gateway_http_client_factory_web.dart'
    as gateway_http;

export 'gateway_http_client_base.dart';

GatewayHttpClient createGatewayHttpClient() {
  return gateway_http.createGatewayHttpClient();
}
