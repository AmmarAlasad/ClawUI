import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/ui/connect_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('connect diagnostics helpers', () {
    test('detects pairing from structured detail code', () {
      const ConnectionCheckResult result = ConnectionCheckResult(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: 120,
        message: 'Gateway pairing required.',
        detailCode: 'PAIRING_REQUIRED',
      );

      expect(isPairingRequired(result), isTrue);
    });

    test('detects insecure context and origin policy issues', () {
      const ConnectionCheckResult identityRequired = ConnectionCheckResult(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: 90,
        message:
            'Device identity required. Use HTTPS, localhost, or allow insecure auth explicitly.',
        detailCode: 'CONTROL_UI_DEVICE_IDENTITY_REQUIRED',
      );
      const ConnectionCheckResult originBlocked = ConnectionCheckResult(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: 90,
        message: 'This origin is not allowed by the gateway control UI policy.',
        detailCode: 'CONTROL_UI_ORIGIN_NOT_ALLOWED',
      );

      expect(isInsecureContextIssue(identityRequired), isTrue);
      expect(isInsecureContextIssue(originBlocked), isTrue);
    });

    test('builds tailored authentication advice for bootstrap tokens', () {
      const ConnectionCheckResult result = ConnectionCheckResult(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: 80,
        message: 'Bootstrap token invalid.',
        detailCode: 'AUTH_BOOTSTRAP_TOKEN_INVALID',
      );

      expect(isAuthenticationIssue(result), isTrue);
      expect(
        authenticationActionFor(result),
        contains('Generate a fresh pairing/bootstrap secret'),
      );
    });

    test('uses recommended next step when available', () {
      const ConnectionCheckResult result = ConnectionCheckResult(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: 80,
        message: 'Gateway authentication failed.',
        recommendedNextStep: 'wait_then_retry',
      );

      expect(
        authenticationActionFor(result),
        'Wait a moment, then run the test again.',
      );
    });
  });
}
