import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class CronScreen extends StatelessWidget {
  const CronScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<CronJob> jobs = AppScope.of(context).cronJobs;
    final int warningCount = jobs
        .where((CronJob job) => job.health != JobHealth.healthy)
        .length;

    return ScreenScaffold(
      title: 'Cron',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ScreenIntro(
            eyebrow: 'Scheduler Health',
            title: warningCount == 0
                ? 'Cron jobs are on schedule.'
                : '$warningCount jobs need operator attention.',
            description:
                'Track schedule cadence, recent runs, and degraded jobs from the mobile shell.',
          ),
          const SizedBox(height: 16),
          const SectionTitle('Jobs'),
          if (jobs.isEmpty)
            const EmptyState(
              title: 'No cron jobs found',
              message:
                  'Cron data will appear here after the next successful refresh.',
            ),
          ...jobs.map(
            (CronJob job) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClawCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            job.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        _HealthBadge(job.health),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(job.schedule),
                    const SizedBox(height: 8),
                    Text('Next run: ${job.nextRun}'),
                    Text('Last run: ${job.lastRun}'),
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

class _HealthBadge extends StatelessWidget {
  const _HealthBadge(this.health);

  final JobHealth health;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (health) {
      JobHealth.healthy => Theme.of(context).colorScheme.primary,
      JobHealth.warning => const Color(0xFFF59E0B),
      JobHealth.stalled => Colors.redAccent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(health.name),
    );
  }
}
