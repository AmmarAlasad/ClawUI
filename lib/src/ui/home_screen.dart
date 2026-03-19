import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'session_overview.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _sessionSearchController = TextEditingController();
  DashboardSessionFilter _sessionFilter = DashboardSessionFilter.all;
  DashboardSessionSort _sessionSort = DashboardSessionSort.recent;

  @override
  void dispose() {
    _sessionSearchController.dispose();
    super.dispose();
  }

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
    final ThemeData theme = Theme.of(context);
    final List<SessionInfo> sessions = buildVisibleDashboardSessions(
      source: dashboard.sessions,
      unreadKeys: controller.sessionsWithUnread,
      filter: _sessionFilter,
      sort: _sessionSort,
      query: _sessionSearchController.text,
    );

    return ScreenScaffold(
      title: 'Dashboard',
      subtitle: controller.profile?.endpointLabel,
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
                ? 'Pull current session, node pairing, and cron state from the active gateway profile.'
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
                            ? theme.colorScheme.primary
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
                    MetricChip(
                      label: 'Auth',
                      value: status.authenticated ? 'OK' : 'Denied',
                    ),
                    MetricChip(label: 'Jobs', value: '${status.runningJobs}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle(
            'Sessions',
            trailing: Text(
              '${sessions.length}/${dashboard.sessions.length} visible',
              style: theme.textTheme.labelMedium,
            ),
          ),
          ClawCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _sessionSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search sessions by title, key, or state',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _sessionSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _sessionSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _sessionFilter == DashboardSessionFilter.all,
                      onSelected: (_) {
                        setState(() => _sessionFilter = DashboardSessionFilter.all);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Unread'),
                      selected: _sessionFilter == DashboardSessionFilter.unread,
                      onSelected: (_) {
                        setState(() => _sessionFilter = DashboardSessionFilter.unread);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: _sessionFilter == DashboardSessionFilter.active,
                      onSelected: (_) {
                        setState(() => _sessionFilter = DashboardSessionFilter.active);
                      },
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<DashboardSessionSort>(
                      segments: const <ButtonSegment<DashboardSessionSort>>[
                        ButtonSegment<DashboardSessionSort>(
                          value: DashboardSessionSort.recent,
                          label: Text('Recent'),
                          icon: Icon(Icons.schedule_rounded),
                        ),
                        ButtonSegment<DashboardSessionSort>(
                          value: DashboardSessionSort.title,
                          label: Text('Title'),
                          icon: Icon(Icons.sort_by_alpha_rounded),
                        ),
                      ],
                      selected: <DashboardSessionSort>{_sessionSort},
                      onSelectionChanged: (Set<DashboardSessionSort> value) {
                        setState(() => _sessionSort = value.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (sessions.isEmpty)
                  const EmptyState(
                    title: 'No matching sessions',
                    message: 'Try a different filter or refresh the gateway snapshot.',
                  )
                else
                  ...sessions.map(
                    (SessionInfo item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SessionCard(
                        session: item,
                        isActive: item.key == controller.activeSessionKey,
                        isUnread: controller.sessionsWithUnread.contains(item.key),
                        onOpen: () async {
                          await controller.setActiveSessionKey(item.key);
                          controller.setTabIndex(1);
                        },
                      ),
                    ),
                  ),
              ],
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
          const SizedBox(height: 20),
          const SectionTitle('Skills'),
          if (dashboard.skills.isEmpty)
            const EmptyState(
              title: 'No skill status available',
              message:
                  'Skill health will appear here once the gateway exposes the operator skill report.',
            ),
          ...dashboard.skills.map(
            (SkillInfo item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.displayName),
                  subtitle: Text(item.detail),
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isActive,
    required this.isUnread,
    required this.onOpen,
  });

  final SessionInfo session;
  final bool isActive;
  final bool isUnread;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = isActive
        ? theme.colorScheme.primary
        : isUnread
        ? Colors.orangeAccent
        : theme.colorScheme.outline;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onOpen();
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : theme.colorScheme.surface,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.forum_outlined, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: Colors.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      session.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _SessionMetaChip(
                          icon: Icons.schedule_rounded,
                          label: session.updatedAgo,
                        ),
                        _SessionMetaChip(
                          icon: Icons.label_outline_rounded,
                          label: session.state,
                        ),
                        if (isActive)
                          const _SessionMetaChip(
                            icon: Icons.check_circle_rounded,
                            label: 'Open now',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionMetaChip extends StatelessWidget {
  const _SessionMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
