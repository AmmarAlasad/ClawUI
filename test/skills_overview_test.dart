import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/ui/skills_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<SkillInfo> skills = <SkillInfo>[
    const SkillInfo(
      name: 'github',
      status: 'Enabled',
      detail: 'Ready',
      group: 'Built-in',
      inputPath: '/tmp/github.token',
    ),
    const SkillInfo(
      name: 'mcporter',
      status: 'Blocked',
      detail: 'Missing allowlist entry',
      group: 'Installed',
    ),
    const SkillInfo(
      name: 'weather',
      status: 'Disabled',
      detail: 'Disabled by config',
      group: 'Core',
    ),
  ];

  test('issues filter keeps blocked and disabled skills', () {
    final List<SkillInfo> result = buildVisibleSkills(
      source: skills,
      filter: SkillsFilter.issues,
    );

    expect(result.map((SkillInfo item) => item.name), <String>[
      'mcporter',
      'weather',
    ]);
  });

  test('configurable filter keeps only input-capable skills', () {
    final List<SkillInfo> result = buildVisibleSkills(
      source: skills,
      filter: SkillsFilter.configurable,
    );

    expect(result.single.name, 'github');
  });

  test('query matches display name detail status and path', () {
    expect(
      buildVisibleSkills(source: skills, query: 'git').single.name,
      'github',
    );
    expect(
      buildVisibleSkills(source: skills, query: 'allowlist').single.name,
      'mcporter',
    );
    expect(
      buildVisibleSkills(source: skills, query: 'disabled').single.name,
      'weather',
    );
    expect(
      buildVisibleSkills(source: skills, query: 'token').single.name,
      'github',
    );
  });

  test('summary counters stay accurate', () {
    expect(countSkillsNeedingAttention(skills), 2);
    expect(countConfigurableSkills(skills), 1);
  });
}
