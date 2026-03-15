import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<SkillInfo> skills = AppScope.of(context).skills;
    final Map<String, List<SkillInfo>> grouped = <String, List<SkillInfo>>{};
    for (final SkillInfo skill in skills) {
      grouped.putIfAbsent(skill.normalizedGroup, () => <SkillInfo>[]).add(skill);
    }
    final List<String> groupOrder = <String>[
      'Core',
      'Built-in',
      'Installed',
      ...grouped.keys.where(
        (String key) => !<String>{'Core', 'Built-in', 'Installed'}.contains(key),
      ),
    ].where(grouped.containsKey).toList();
    return ScreenScaffold(
      title: 'Skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const ScreenIntro(
            eyebrow: 'Skill Status',
            title: 'Browse skills by source and status.',
            description:
                'This view mirrors the OpenClaw skill report and groups entries by where they come from.',
          ),
          const SizedBox(height: 16),
          if (skills.isEmpty)
            const EmptyState(
              title: 'No skill report available',
              message:
                  'The gateway did not return a skill status payload for this connection.',
            ),
          ...groupOrder.map((String groupName) {
            final List<SkillInfo> items = grouped[groupName]!..sort(
              (SkillInfo a, SkillInfo b) =>
                  a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle(
                  groupName,
                  trailing: Text('${items.length}'),
                ),
                ...items.map(
                  (SkillInfo item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClawCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.displayName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(item.detail),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SkillStatusChip(status: item.status),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SkillStatusChip extends StatelessWidget {
  const _SkillStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final String normalized = status.trim().toLowerCase();
    final Color color = switch (normalized) {
      'enabled' => Colors.green,
      'disabled' => Colors.blueGrey,
      'blocked' => Colors.orange,
      'missing deps' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
