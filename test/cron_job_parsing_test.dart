import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseCronJobsFromPayload keeps delivery and target metadata', () {
    final List<CronJob> jobs = parseCronJobsFromPayload(<String, dynamic>{
      'details': <String, dynamic>{
        'jobs': <Map<String, dynamic>>[
          <String, dynamic>{
            'jobId': 'job-1',
            'name': 'daily-summary',
            'enabled': true,
            'schedule': <String, dynamic>{'kind': 'cron', 'expr': '0 9 * * *'},
            'nextRunAtMs': DateTime.now()
                .subtract(const Duration(minutes: 15))
                .millisecondsSinceEpoch,
            'state': <String, dynamic>{
              'lastRunAtMs': DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
              'lastStatus': 'ok',
            },
            'sessionTarget': 'isolated',
            'payload': <String, dynamic>{'kind': 'agentTurn'},
            'delivery': <String, dynamic>{
              'mode': 'announce',
              'channel': 'telegram',
              'to': '1602825125',
            },
          },
          <String, dynamic>{
            'id': 'job-2',
            'enabled': false,
            'schedule': <String, dynamic>{'kind': 'every', 'everyMs': 60000},
            'state': <String, dynamic>{'lastStatus': 'error'},
            'delivery': <String, dynamic>{'mode': 'none'},
            'sessionTarget': 'main',
            'payload': <String, dynamic>{'kind': 'systemEvent'},
          },
        ],
      },
    });

    expect(jobs, hasLength(2));

    expect(jobs[0].health, JobHealth.healthy);
    expect(jobs[0].enabled, isTrue);
    expect(jobs[0].deliveryLabel, 'announce · telegram → 1602825125');
    expect(jobs[0].targetLabel, 'isolated · agent turn');

    expect(jobs[1].health, JobHealth.stalled);
    expect(jobs[1].enabled, isFalse);
    expect(jobs[1].deliveryLabel, 'none');
    expect(jobs[1].targetLabel, 'main · system event');
  });
}
