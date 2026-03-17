import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final List<SkillInfo> skills = controller.skills;
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
                                if (item.detail.trim().isNotEmpty &&
                                    item.detail.trim().toLowerCase() !=
                                        'ready') ...<Widget>[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(item.detail),
                                  ),
                                ],
                                if (item.canConfigureInput) ...<Widget>[
                                  const SizedBox(height: 12),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _showSkillInputDialog(context, item),
                                    icon: const Icon(Icons.tune_rounded),
                                    label: Text(
                                      'Set ${item.inputPath!.split('.').last}',
                                    ),
                                  ),
                                ],
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

Future<void> _showSkillInputDialog(BuildContext context, SkillInfo skill) async {
  final appController = AppScope.read(context);
  final TextEditingController textController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Set ${skill.displayName} input'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              skill.inputPath ?? '',
              style: Theme.of(dialogContext).textTheme.labelMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Value',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              try {
                await appController.setSkillInput(skill, textController.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Updated ${skill.displayName} input.',
                    ),
                  ),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(error.toString()),
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  textController.dispose();
}
