import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DeviceInfo> devices = AppScope.of(context).devices;
    final List<DeviceInfo> pending = devices
        .where((DeviceInfo item) => item.pendingApproval)
        .toList();
    final List<DeviceInfo> paired = devices
        .where((DeviceInfo item) => !item.pendingApproval)
        .toList();

    return ScreenScaffold(
      title: 'Devices',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionTitle('Pending approvals'),
          if (pending.isEmpty)
            const EmptyState(
              title: 'Nothing waiting',
              message: 'New devices will appear here before they are trusted.',
            ),
          ...pending.map(
            (DeviceInfo item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text('${item.platform} • ${item.lastSeen}'),
                      trailing: Text(item.status),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {},
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Trusted devices'),
          ...paired.map(
            (DeviceInfo item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.platform} • Last seen ${item.lastSeen}',
                  ),
                  trailing: Text(item.status),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
