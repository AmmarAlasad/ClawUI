import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parseCronRunsFromPayload handles nested state, result, and delivery data',
    () {
      final List<CronRun> runs = parseCronRunsFromPayload(<String, dynamic>{
        'details': <String, dynamic>{
          'runs': <Map<String, dynamic>>[
            <String, dynamic>{
              'runId': 'run-1',
              'createdAtMs': DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
              'state': <String, dynamic>{
                'status': 'completed',
                'summary': 'Finished hourly UI improvement pass.',
              },
              'runtimeMs': 4200,
              'delivery': <String, dynamic>{
                'status': 'ok',
                'mode': 'announce',
                'delivered': true,
              },
            },
            <String, dynamic>{
              'id': 'run-2',
              'startedAt': DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .millisecondsSinceEpoch,
              'result': <String, dynamic>{
                'status': 'failed',
                'error': <String, dynamic>{
                  'message': 'Push rejected by remote policy.',
                },
              },
              'completedInMs': 900,
              'delivery': <String, dynamic>{
                'mode': 'webhook',
                'delivered': false,
              },
            },
            <String, dynamic>{
              'id': 'run-3',
              'runAtMs': DateTime.now()
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
              'status': 'skip',
              'message': 'Skipped because another run was still active.',
            },
          ],
        },
      });

      expect(runs, hasLength(3));

      expect(runs[0].status, CronRunStatus.ok);
      expect(runs[0].durationLabel, '4s');
      expect(runs[0].deliveryLabel, 'Announce delivered');
      expect(runs[0].summary, 'Finished hourly UI improvement pass.');

      expect(runs[1].status, CronRunStatus.error);
      expect(runs[1].durationLabel, '900ms');
      expect(runs[1].deliveryLabel, 'Webhook not delivered');
      expect(runs[1].summary, 'Push rejected by remote policy.');

      expect(runs[2].status, CronRunStatus.skipped);
      expect(runs[2].summary, 'Skipped because another run was still active.');
    },
  );
}
