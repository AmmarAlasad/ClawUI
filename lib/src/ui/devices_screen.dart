import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final List<DeviceInfo> devices = controller.devices;
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
          ScreenIntro(
            eyebrow: 'Pairing Control',
            title: pending.isEmpty
                ? 'All visible devices are trusted.'
                : '${pending.length} device approvals need attention.',
            description:
                'Use this view to review new mobile clients before they are trusted by the gateway.',
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: ClawCard(
                  child: StatBlock(
                    label: 'Pending',
                    value: '${pending.length}',
                    caption: 'Awaiting approval',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClawCard(
                  child: StatBlock(
                    label: 'Trusted',
                    value: '${paired.length}',
                    caption: 'Active device profiles',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                      subtitle: Text('${item.platform} - ${item.lastSeen}'),
                      trailing: Text(item.status),
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                        onPressed: item.requestId == null
                                ? null
                                : () async {
                                    try {
                                      await controller.rejectDevice(
                                        item.requestId!,
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                        onPressed: item.requestId == null
                                ? null
                                : () async {
                                    try {
                                      await controller.approveDevice(
                                        item.requestId!,
                                      );
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(error.toString()),
                                          ),
                                        );
                                      }
                                    }
                                  },
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
          if (paired.isEmpty)
            const EmptyState(
              title: 'No trusted devices yet',
              message:
                  'Approved devices will appear here once the gateway has paired clients.',
            ),
          ...paired.map(
            (DeviceInfo item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.platform} - Last seen ${item.lastSeen}',
                      ),
                      trailing: Text(item.status),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: item.deviceId == null
                            ? null
                            : () async {
                                try {
                                  await controller.removeTrustedDevice(item);
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(error.toString()),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
