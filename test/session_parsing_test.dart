import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveSessionTitle', () {
    test('uses richer fallback fields before raw keys', () {
      expect(resolveSessionTitle(<String, dynamic>{'subject': 'Incident triage'}), 'Incident triage');
      expect(resolveSessionTitle(<String, dynamic>{'room': 'Ops war room'}), 'Ops war room');
      expect(resolveSessionTitle(<String, dynamic>{'space': 'Security'}), 'Security');
      expect(resolveSessionTitle(<String, dynamic>{'key': 'main'}), 'main');
      expect(resolveSessionTitle(<String, dynamic>{}), 'Session');
    });
  });

  group('resolveSessionState', () {
    test('prefers explicit status labels and falls back to lifecycle hints', () {
      expect(resolveSessionState(<String, dynamic>{'statusLabel': 'Needs review'}), 'Needs review');
      expect(resolveSessionState(<String, dynamic>{'state': 'running'}), 'running');
      expect(resolveSessionState(<String, dynamic>{'abortedLastRun': true}), 'Aborted');
      expect(resolveSessionState(<String, dynamic>{'systemSent': true}), 'System');
      expect(resolveSessionState(<String, dynamic>{}), 'session');
    });
  });

  group('resolveSessionUpdatedAtMs', () {
    test('accepts common updated and fallback timestamp fields', () {
      expect(resolveSessionUpdatedAtMs(<String, dynamic>{'updatedAtMs': 42}), 42);
      expect(resolveSessionUpdatedAtMs(<String, dynamic>{'lastMessageAt': 84}), 84);
      expect(resolveSessionUpdatedAtMs(<String, dynamic>{'createdAtMs': 126}), 126);
      expect(resolveSessionUpdatedAtMs(<String, dynamic>{'timestamp': 168}), 168);
      expect(resolveSessionUpdatedAtMs(<String, dynamic>{}), isNull);
    });
  });
}
