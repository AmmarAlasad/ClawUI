import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'skills_overview.dart';
import 'widgets.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  SkillsFilter _filter = SkillsFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final List<SkillInfo> skills = controller.skills;
    final List<SkillInfo> visibleSkills = buildVisibleSkills(
      source: skills,
      filter: _filter,
      query: _searchController.text,
    );
    final Map<String, List<SkillInfo>> grouped = <String, List<SkillInfo>>{};
    for (final SkillInfo skill in visibleSkills) {
      grouped
          .putIfAbsent(skill.normalizedGroup, () => <SkillInfo>[])
          .add(skill);
    }
    final List<String> groupOrder = <String>[
      'Core',
      'Built-in',
      'Installed',
      ...grouped.keys.where(
        (String key) =>
            !<String>{'Core', 'Built-in', 'Installed'}.contains(key),
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
                'Search the skill report, focus on problems, and jump straight to configurable inputs.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _SummaryChip(
                label: 'Total',
                value: '${skills.length}',
                icon: Icons.extension_rounded,
              ),
              _SummaryChip(
                label: 'Needs attention',
                value: '${countSkillsNeedingAttention(skills)}',
                icon: Icons.warning_amber_rounded,
              ),
              _SummaryChip(
                label: 'Configurable',
                value: '${countConfigurableSkills(skills)}',
                icon: Icons.tune_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search skills by name, group, status, or config path',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                selected: _filter == SkillsFilter.all,
                label: const Text('All'),
                onSelected: (_) => setState(() => _filter = SkillsFilter.all),
              ),
              FilterChip(
                selected: _filter == SkillsFilter.issues,
                label: const Text('Needs attention'),
                onSelected: (_) =>
                    setState(() => _filter = SkillsFilter.issues),
              ),
              FilterChip(
                selected: _filter == SkillsFilter.configurable,
                label: const Text('Configurable'),
                onSelected: (_) =>
                    setState(() => _filter = SkillsFilter.configurable),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (skills.isEmpty)
            const EmptyState(
              title: 'No skill report available',
              message:
                  'The gateway did not return a skill status payload for this connection.',
            )
          else if (visibleSkills.isEmpty)
            const EmptyState(
              title: 'No matching skills',
              message: 'Try a broader search or switch back to all skills.',
            )
          else
            ...groupOrder.map((String groupName) {
              final List<SkillInfo> items = grouped[groupName]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionTitle(groupName, trailing: Text('${items.length}')),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      _InfoPill(
                                        icon: Icons.folder_open_rounded,
                                        label: item.normalizedGroup,
                                      ),
                                      if (item.canConfigureInput)
                                        _InfoPill(
                                          icon: Icons.tune_rounded,
                                          label: item.inputPath!
                                              .split('/')
                                              .last,
                                        ),
                                    ],
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
                                        'Set ${item.inputPath!.split('/').last}',
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
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

Future<void> _showSkillInputDialog(
  BuildContext context,
  SkillInfo skill,
) async {
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
              decoration: const InputDecoration(labelText: 'Value'),
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
                    content: Text('Updated ${skill.displayName} input.'),
                  ),
                );
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(error.toString())),
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
