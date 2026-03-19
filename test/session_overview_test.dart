import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/ui/session_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('updatedAgoRank', () {
    test('parses compact and long relative labels', () {
      expect(updatedAgoRank('Updated 3m ago'), 3);
      expect(updatedAgoRank('Updated 2h ago'), 120);
      expect(updatedAgoRank('Last updated 1 day ago'), 1440);
      expect(updatedAgoRank('just now'), 0);
    });
  });

  group('buildVisibleDashboardSessions', () {
    final DateTime now = DateTime(2026, 3, 19, 4, 13);
    final List<SessionInfo> sessions = <SessionInfo>[
      SessionInfo(
        key: 'nightly-summary',
        title: 'Nightly summary',
        updatedAgo: 'Updated 48m ago',
        state: 'Idle',
        updatedAtMs: now.subtract(const Duration(minutes: 48)).millisecondsSinceEpoch,
      ),
      SessionInfo(
        key: 'investigate-gpu-node-drift',
        title: 'Investigate GPU node drift',
        updatedAgo: 'Updated 14m ago',
        state: 'Needs review',
        updatedAtMs: now.subtract(const Duration(minutes: 14)).millisecondsSinceEpoch,
      ),
      SessionInfo(
        key: 'deploy-staging-rollback',
        title: 'Deploy staging rollback',
        updatedAgo: 'Updated 3m ago',
        state: 'Running',
        updatedAtMs: now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
      ),
    ];

    test('sorts most recent first by default', () {
      final List<SessionInfo> result = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{},
        filter: DashboardSessionFilter.all,
        sort: DashboardSessionSort.recent,
        now: now,
      );

      expect(result.map((SessionInfo item) => item.key), <String>[
        'deploy-staging-rollback',
        'investigate-gpu-node-drift',
        'nightly-summary',
      ]);
    });

    test('filters unread sessions', () {
      final List<SessionInfo> result = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{'investigate-gpu-node-drift'},
        filter: DashboardSessionFilter.unread,
        sort: DashboardSessionSort.recent,
        now: now,
      );

      expect(result.map((SessionInfo item) => item.key), <String>[
        'investigate-gpu-node-drift',
      ]);
    });

    test('searches title key and state fields', () {
      final List<SessionInfo> byTitle = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{},
        filter: DashboardSessionFilter.all,
        sort: DashboardSessionSort.recent,
        query: 'gpu',
        now: now,
      );
      final List<SessionInfo> byState = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{},
        filter: DashboardSessionFilter.all,
        sort: DashboardSessionSort.recent,
        query: 'running',
        now: now,
      );

      expect(byTitle.single.key, 'investigate-gpu-node-drift');
      expect(byState.single.key, 'deploy-staging-rollback');
    });

    test('active filter includes running and recent sessions', () {
      final List<SessionInfo> result = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{},
        filter: DashboardSessionFilter.active,
        sort: DashboardSessionSort.recent,
        now: now,
      );

      expect(result.map((SessionInfo item) => item.key), <String>[
        'deploy-staging-rollback',
        'investigate-gpu-node-drift',
        'nightly-summary',
      ]);
    });

    test('title sort is alphabetical', () {
      final List<SessionInfo> result = buildVisibleDashboardSessions(
        source: sessions,
        unreadKeys: const <String>{},
        filter: DashboardSessionFilter.all,
        sort: DashboardSessionSort.title,
        now: now,
      );

      expect(result.map((SessionInfo item) => item.title), <String>[
        'Deploy staging rollback',
        'Investigate GPU node drift',
        'Nightly summary',
      ]);
    });
  });
}
