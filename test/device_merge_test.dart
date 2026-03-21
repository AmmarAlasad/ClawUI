import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mergeOpenClawDevices', () {
    test('merges pairing and node records for the same device id', () {
      final List<DeviceInfo> merged = mergeOpenClawDevices(
        const <DeviceInfo>[
          DeviceInfo(
            name: 'Pixel 9 Pro',
            platform: 'Android',
            status: 'Trusted',
            lastSeen: '18m ago',
            deviceId: 'device-123',
            role: 'operator',
          ),
        ],
        const <DeviceInfo>[
          DeviceInfo(
            name: 'Pixel 9 Pro',
            platform: 'Android',
            status: 'Connected',
            lastSeen: 'Now',
            deviceId: 'device-123',
            role: 'operator',
          ),
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.single.status, 'Trusted');
      expect(merged.single.lastSeen, 'Now');
      expect(merged.single.deviceId, 'device-123');
    });

    test('keeps pending approvals ahead of non-pending entries', () {
      final List<DeviceInfo> merged = mergeOpenClawDevices(
        const <DeviceInfo>[
          DeviceInfo(
            name: 'Field iPhone',
            platform: 'iOS',
            status: 'Pending approval',
            lastSeen: '1m ago',
            requestId: 'req-1',
            pendingApproval: true,
          ),
        ],
        const <DeviceInfo>[
          DeviceInfo(
            name: 'Pixel 9 Pro',
            platform: 'Android',
            status: 'Connected',
            lastSeen: 'Now',
            deviceId: 'device-123',
          ),
        ],
      );

      expect(merged, hasLength(2));
      expect(merged.first.pendingApproval, isTrue);
      expect(merged.first.requestId, 'req-1');
    });

    test(
      'falls back to name and platform matching when no device id exists',
      () {
        final List<DeviceInfo> merged = mergeOpenClawDevices(
          const <DeviceInfo>[
            DeviceInfo(
              name: 'Galaxy Tab Relay',
              platform: 'Android',
              status: 'Trusted',
              lastSeen: '18m ago',
            ),
          ],
          const <DeviceInfo>[
            DeviceInfo(
              name: 'Galaxy Tab Relay',
              platform: 'Android',
              status: 'Offline',
              lastSeen: '2h ago',
            ),
          ],
        );

        expect(merged, hasLength(1));
        expect(merged.single.status, 'Trusted');
        expect(merged.single.lastSeen, '18m ago');
      },
    );
  });
}
