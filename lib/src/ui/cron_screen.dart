import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class CronScreen extends StatelessWidget {
  const CronScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final List<CronJob> jobs = controller.cronJobs;
    final List<CronRun> runs = controller.cronRuns;
    final String? selectedJobId = controller.selectedCronJobId;
    final CronJob? selectedJob = jobs.cast<CronJob?>().firstWhere(
      (CronJob? job) => job?.id == selectedJobId,
      orElse: () => null,
    );
    final int warningCount = jobs
        .where((CronJob job) => job.health != JobHealth.healthy)
        .length;
    final int healthyRuns = runs
        .where((CronRun run) => run.status == CronRunStatus.ok)
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
                'Track schedule cadence, inspect a job, and review its recent run history from the mobile shell.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              MetricChip(label: 'Jobs', value: '${jobs.length}'),
              MetricChip(label: 'Warnings', value: '$warningCount'),
              MetricChip(
                label: 'Recent OK',
                value: runs.isEmpty ? '—' : '$healthyRuns/${runs.length}',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle('Jobs'),
          if (jobs.isEmpty)
            const EmptyState(
              title: 'No cron jobs found',
              message:
                  'Cron data will appear here after the next successful refresh.',
            )
          else ...<Widget>[
            ...jobs.map(
              (CronJob job) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CronJobCard(
                  job: job,
                  selected: job.id == selectedJobId,
                  onTap: () => controller.selectCronJob(job.id),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SectionTitle('Recent runs'),
            if (selectedJob == null)
              const EmptyState(
                title: 'Select a job',
                message: 'Choose a cron job above to inspect its latest runs.',
              )
            else
              _CronRunsPanel(
                job: selectedJob,
                runs: runs,
                loading: controller.loadingCronRuns,
              ),
          ],
        ],
      ),
    );
  }
}

class _CronJobCard extends StatelessWidget {
  const _CronJobCard({
    required this.job,
    required this.selected,
    required this.onTap,
  });

  final CronJob job;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ClawCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      job.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.radio_button_checked_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  if (selected) const SizedBox(width: 10),
                  _HealthBadge(job.health),
                ],
              ),
              const SizedBox(height: 10),
              Text(job.schedule),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (!job.enabled)
                    const _MetaBadge(label: 'Disabled', color: Colors.blueGrey),
                  if (job.targetLabel != null)
                    _MetaBadge(
                      label: job.targetLabel!,
                      color: theme.colorScheme.primary,
                    ),
                  if (job.deliveryLabel != null)
                    _MetaBadge(
                      label: job.deliveryLabel!,
                      color: const Color(0xFFF59E0B),
                    ),
                ],
              ),
              if (!job.enabled ||
                  job.targetLabel != null ||
                  job.deliveryLabel != null)
                const SizedBox(height: 10),
              Text('Next run: ${job.nextRun}'),
              Text('Last run: ${job.lastRun}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CronRunsPanel extends StatelessWidget {
  const _CronRunsPanel({
    required this.job,
    required this.runs,
    required this.loading,
  });

  final CronJob job;
  final List<CronRun> runs;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const ClawCard(child: Center(child: CircularProgressIndicator()));
    }
    if (runs.isEmpty) {
      return EmptyState(
        title: 'No recent runs for ${job.name}',
        message:
            'The gateway did not return any run history for the selected job yet.',
      );
    }
    return ClawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            job.name,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Showing the latest ${runs.length} runs.'),
          const SizedBox(height: 16),
          ...runs.map(
            (CronRun run) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CronRunTile(run: run),
            ),
          ),
        ],
      ),
    );
  }
}

class _CronRunTile extends StatelessWidget {
  const _CronRunTile({required this.run});

  final CronRun run;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (run.status) {
      CronRunStatus.ok => Theme.of(context).colorScheme.primary,
      CronRunStatus.error => Colors.redAccent,
      CronRunStatus.skipped => const Color(0xFFF59E0B),
      CronRunStatus.unknown => Colors.blueGrey,
    };
    final String statusLabel = switch (run.status) {
      CronRunStatus.ok => 'OK',
      CronRunStatus.error => 'Error',
      CronRunStatus.skipped => 'Skipped',
      CronRunStatus.unknown => 'Unknown',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusLabel),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(run.startedAtLabel)),
              if (run.durationLabel != null) Text(run.durationLabel!),
            ],
          ),
          if (run.deliveryLabel != null) ...<Widget>[
            const SizedBox(height: 10),
            Text('Delivery: ${run.deliveryLabel!}'),
          ],
          if (run.summary != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(run.summary!),
          ],
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

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}
