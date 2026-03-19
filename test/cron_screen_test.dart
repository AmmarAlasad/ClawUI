import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo repository exposes recent cron runs for a selected job', () async {
    final DemoOpenClawRepository repository = DemoOpenClawRepository();
    const ConnectionProfile profile = ConnectionProfile(
      targetKind: ConnectionTargetKind.directUrl,
      authMode: AuthMode.token,
      directUrl: 'https://gateway.example.com',
      token: 'demo-token',
      demoMode: true,
    );

    final List<CronJob> jobs = await repository.fetchCronJobs(profile);
    final List<CronRun> runs = await repository.fetchCronRuns(
      profile,
      jobId: jobs.first.id,
    );

    expect(jobs.first.id, 'inventory-sync');
    expect(runs, isNotEmpty);
    expect(runs.first.status, CronRunStatus.ok);
    expect(runs.first.deliveryLabel, 'Announced');
  });
}
