import 'gateway_ws_client_base.dart';
import 'gateway_ws_client_factory_stub.dart'
    if (dart.library.io) 'gateway_ws_client_factory_io.dart'
    as gateway_ws;

export 'gateway_ws_client_base.dart';

GatewayWsClient createGatewayWsClient() {
  return gateway_ws.createGatewayWsClient();
}
