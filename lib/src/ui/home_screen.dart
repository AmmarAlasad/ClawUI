import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final DashboardSnapshot? dashboard = controller.dashboard;
    if (dashboard == null) {
      return const ScreenScaffold(
        title: 'Dashboard',
        child: EmptyState(
          title: 'No gateway data yet',
          message: 'Connect a profile and refresh to populate the dashboard.',
        ),
      );
    }

    final GatewayStatus status = dashboard.gatewayStatus;
    return ScreenScaffold(
      title: 'Dashboard',
      subtitle: controller.profile?.serverUrl,
      actions: <Widget>[
        IconButton(
          onPressed: controller.busy ? null : controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ScreenIntro(
            eyebrow: 'Gateway Overview',
            title: status.online
                ? 'OpenClaw is reachable.'
                : 'Gateway connection is degraded.',
            description: controller.lastUpdatedAt == null
                ? 'Pull current session, device, and cron state from the active gateway profile.'
                : 'Last refreshed at ${TimeOfDay.fromDateTime(controller.lastUpdatedAt!).format(context)}.',
          ),
          const SizedBox(height: 16),
          if (controller.error != null) ...<Widget>[
            StatusBanner(
              title: 'Refresh issue',
              message: controller.error!,
              tone: BannerTone.warning,
            ),
            const SizedBox(height: 16),
          ],
          ClawCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: status.online
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.version,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text('${status.latencyMs} ms'),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    MetricChip(
                      label: 'Sessions',
                      value: '${status.activeSessions}',
                    ),
                    MetricChip(
                      label: 'Devices',
                      value: '${status.connectedDevices}',
                    ),
                    MetricChip(
                      label: 'Approvals',
                      value: '${status.pendingApprovals}',
                    ),
                    MetricChip(label: 'Jobs', value: '${status.runningJobs}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Active Sessions'),
          ...dashboard.sessions.map(
            (SessionInfo item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.title),
                  subtitle: Text(item.updatedAgo),
                  trailing: Text(item.state),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SectionTitle('Overview'),
          Row(
            children: <Widget>[
              Expanded(
                child: ClawCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Connected devices'),
                      const SizedBox(height: 8),
                      Text(
                        '${dashboard.connectedDevices.length}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status.pendingApprovals == 0
                            ? 'All devices trusted'
                            : '${status.pendingApprovals} awaiting approval',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClawCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Cron health'),
                      const SizedBox(height: 8),
                      Text(
                        dashboard.cronSummary.nextRunLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dashboard.cronSummary.overdueJobs == 0
                            ? 'No overdue jobs'
                            : '${dashboard.cronSummary.overdueJobs} overdue jobs',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
