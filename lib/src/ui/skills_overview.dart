import '../core/models.dart';

enum SkillsFilter { all, issues, configurable }

List<SkillInfo> buildVisibleSkills({
  required List<SkillInfo> source,
  SkillsFilter filter = SkillsFilter.all,
  String query = '',
}) {
  final String normalizedQuery = query.trim().toLowerCase();
  final List<SkillInfo> filtered = source.where((SkillInfo skill) {
    if (filter == SkillsFilter.issues && !skillNeedsAttention(skill)) {
      return false;
    }
    if (filter == SkillsFilter.configurable && !skill.canConfigureInput) {
      return false;
    }
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return skill.displayName.toLowerCase().contains(normalizedQuery) ||
        skill.name.toLowerCase().contains(normalizedQuery) ||
        skill.status.toLowerCase().contains(normalizedQuery) ||
        skill.detail.toLowerCase().contains(normalizedQuery) ||
        skill.normalizedGroup.toLowerCase().contains(normalizedQuery) ||
        (skill.inputPath?.toLowerCase().contains(normalizedQuery) ?? false);
  }).toList();

  filtered.sort(
    (SkillInfo a, SkillInfo b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );
  return filtered;
}

bool skillNeedsAttention(SkillInfo skill) {
  final String normalized = skill.status.trim().toLowerCase();
  return normalized == 'blocked' ||
      normalized == 'missing deps' ||
      normalized == 'disabled';
}

int countSkillsNeedingAttention(List<SkillInfo> skills) {
  return skills.where(skillNeedsAttention).length;
}

int countConfigurableSkills(List<SkillInfo> skills) {
  return skills.where((SkillInfo skill) => skill.canConfigureInput).length;
}
